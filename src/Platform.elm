module Platform exposing
    ( Program, worker
    , Task, ProcessId
    , Router, sendToApp, sendToSelf
    )

{-|


# Programs

@docs Program, worker


# Platform Internals


## Tasks and Processes

@docs Task, ProcessId


## Effect Manager Helpers

An extremely tiny portion of library authors should ever write effect managers.
Fundamentally, Elm needs maybe 10 of them total. I get that people are smart,
curious, etc. but that is not a substitute for a legitimate reason to make an
effect manager. Do you have an _organic need_ this fills? Or are you just
curious? Public discussions of your explorations should be framed accordingly.

@docs Router, sendToApp, sendToSelf

-}

-- import Json.Decode exposing (Decoder)
-- import Json.Encode as Encode

import Basics exposing (..)
import Char exposing (Char)
import Debug
import Dict exposing (Dict)
import Elm.Kernel.Basics
import Elm.Kernel.Platform
import List exposing ((::))
import Maybe exposing (Maybe(..))
import Platform.Bag as Bag
import Platform.Cmd as Cmd exposing (Cmd)
import Platform.RawScheduler as RawScheduler
import Platform.Sub as Sub exposing (Sub)
import Result exposing (Result(..))
import String exposing (String)
import Tuple


type Decoder flags
    = Decoder (Decoder flags)


type EncodeValue
    = EncodeValue EncodeValue



-- PROGRAMS


{-| A `Program` describes an Elm program! How does it react to input? Does it
show anything on screen? Etc.
-}
type Program flags model msg
    = Program
        (Decoder flags
         -> DebugMetadata
         -> RawJsObject { args : Maybe (RawJsObject flags) }
         ->
            RawJsObject
                { ports :
                    RawJsObject
                        { outgoingPortName : OutgoingPort
                        , incomingPortName : IncomingPort
                        }
                }
        )


{-| Create a [headless] program with no user interface.

This is great if you want to use Elm as the &ldquo;brain&rdquo; for something
else. For example, you could send messages out ports to modify the DOM, but do
all the complex logic in Elm.

[headless]: https://en.wikipedia.org/wiki/Headless_software

Initializing a headless program from JavaScript looks like this:

```javascript
var app = Elm.MyThing.init();
```

If you _do_ want to control the user interface in Elm, the [`Browser`][browser]
module has a few ways to create that kind of `Program` instead!

[headless]: https://en.wikipedia.org/wiki/Headless_software
[browser]: /packages/elm/browser/latest/Browser

-}
worker :
    { init : flags -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    }
    -> Program flags model msg
worker impl =
    makeProgramCallable
        (Program
            (\flagsDecoder _ args ->
                initialize
                    flagsDecoder
                    args
                    impl
                    { stepperBuilder = \_ _ -> \_ _ -> ()
                    , setupOutgoingPort = setupOutgoingPort
                    , setupIncomingPort = setupIncomingPort
                    , setupEffects = instantiateEffectManager
                    , dispatchEffects = dispatchEffects
                    }
            )
        )



-- TASKS and PROCESSES


{-| Head over to the documentation for the [`Task`](Task) module for more
information on this. It is only defined here because it is a platform
primitive.
-}
type Task err ok
    = Task (RawScheduler.Task (Result err ok))


{-| Head over to the documentation for the [`Process`](Process) module for
information on this. It is only defined here because it is a platform
primitive.
-}
type ProcessId
    = ProcessId (RawScheduler.ProcessId Never)



-- EFFECT MANAGER INTERNALS


{-| An effect manager has access to a “router” that routes messages between
the main app and your individual effect manager.
-}
type Router appMsg selfMsg
    = Router
        { sendToApp : appMsg -> ()
        , selfProcess : RawScheduler.ProcessId (ReceivedData appMsg selfMsg)
        }


{-| Send the router a message for the main loop of your app. This message will
be handled by the overall `update` function, just like events from `Html`.
-}
sendToApp : Router msg a -> msg -> Task x ()
sendToApp (Router router) msg =
    Task
        (RawScheduler.SyncAction
            (\() ->
                RawScheduler.Value (Ok (router.sendToApp msg))
            )
        )


{-| Send the router a message for your effect manager. This message will
be routed to the `onSelfMsg` function, where you can update the state of your
effect manager as necessary.

As an example, the effect manager for web sockets

-}
sendToSelf : Router a msg -> msg -> Task x ()
sendToSelf (Router router) msg =
    Task
        (RawScheduler.andThen
            (\() -> RawScheduler.Value (Ok ()))
            (RawScheduler.send
                router.selfProcess
                (Self msg)
            )
        )



-- HELPERS --


setupOutgoingPort : (EncodeValue -> ()) -> RawScheduler.ProcessId (ReceivedData Never Never)
setupOutgoingPort outgoingPortSend =
    let
        init =
            Task (RawScheduler.Value (Ok ()))

        onSelfMsg _ selfMsg () =
            never selfMsg

        execInOrder : List EncodeValue -> RawScheduler.Task (Result Never ())
        execInOrder cmdList =
            case cmdList of
                first :: rest ->
                    RawScheduler.SyncAction
                        (\() ->
                            let
                                _ =
                                    outgoingPortSend first
                            in
                            execInOrder rest
                        )

                _ ->
                    RawScheduler.Value (Ok ())

        onEffects :
            Router Never Never
            -> List (HiddenMyCmd Never)
            -> List (HiddenMySub Never)
            -> ()
            -> Task Never ()
        onEffects _ cmdList _ () =
            Task (execInOrder (createValuesToSendOutOfPorts cmdList))
    in
    instantiateEffectManager (\msg -> never msg) init onEffects onSelfMsg


setupIncomingPort :
    SendToApp msg
    -> (List (HiddenMySub msg) -> ())
    -> ( RawScheduler.ProcessId (ReceivedData msg Never), EncodeValue -> List (HiddenMySub msg) -> () )
setupIncomingPort sendToApp2 updateSubs =
    let
        init =
            Task (RawScheduler.Value (Ok ()))

        onSelfMsg _ selfMsg () =
            never selfMsg

        onEffects _ _ subList () =
            Task
                (RawScheduler.SyncAction
                    (\() ->
                        let
                            _ =
                                updateSubs subList
                        in
                        RawScheduler.Value (Ok ())
                    )
                )

        onSend value subs =
            List.foldr
                (\sub () ->
                    sendToApp2 (sub value) AsyncUpdate
                )
                ()
                (createIncomingPortConverters subs)
    in
    ( instantiateEffectManager sendToApp2 init onEffects onSelfMsg
    , onSend
    )


dispatchEffects :
    Cmd appMsg
    -> Sub appMsg
    -> Bag.EffectManagerName
    -> RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg)
    -> ()
dispatchEffects cmdBag subBag =
    let
        effectsDict =
            Dict.empty
                |> gatherCmds cmdBag
                |> gatherSubs subBag
    in
    \key selfProcess ->
        let
            ( cmdList, subList ) =
                Maybe.withDefault
                    ( [], [] )
                    (Dict.get (effectManagerNameToString key) effectsDict)

            _ =
                RawScheduler.rawSend
                    selfProcess
                    (App (createHiddenMyCmdList cmdList) (createHiddenMySubList subList))
        in
        ()


gatherCmds :
    Cmd msg
    -> Dict String ( List (Bag.LeafType msg), List (Bag.LeafType msg) )
    -> Dict String ( List (Bag.LeafType msg), List (Bag.LeafType msg) )
gatherCmds cmdBag effectsDict =
    List.foldr
        (\{ home, value } dict -> gatherHelper True home value dict)
        effectsDict
        (unwrapCmd cmdBag)


gatherSubs :
    Sub msg
    -> Dict String ( List (Bag.LeafType msg), List (Bag.LeafType msg) )
    -> Dict String ( List (Bag.LeafType msg), List (Bag.LeafType msg) )
gatherSubs subBag effectsDict =
    List.foldr
        (\{ home, value } dict -> gatherHelper False home value dict)
        effectsDict
        (unwrapSub subBag)


gatherHelper :
    Bool
    -> Bag.EffectManagerName
    -> Bag.LeafType msg
    -> Dict String ( List (Bag.LeafType msg), List (Bag.LeafType msg) )
    -> Dict String ( List (Bag.LeafType msg), List (Bag.LeafType msg) )
gatherHelper isCmd home effectData effectsDict =
    Dict.insert
        (effectManagerNameToString home)
        (createEffect isCmd effectData (Dict.get (effectManagerNameToString home) effectsDict))
        effectsDict


createEffect :
    Bool
    -> Bag.LeafType msg
    -> Maybe ( List (Bag.LeafType msg), List (Bag.LeafType msg) )
    -> ( List (Bag.LeafType msg), List (Bag.LeafType msg) )
createEffect isCmd newEffect maybeEffects =
    let
        ( cmdList, subList ) =
            case maybeEffects of
                Just effects ->
                    effects

                Nothing ->
                    ( [], [] )
    in
    if isCmd then
        ( newEffect :: cmdList, subList )

    else
        ( cmdList, newEffect :: subList )


instantiateEffectManager :
    SendToApp appMsg
    -> Task Never state
    -> (Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> Task Never state)
    -> (Router appMsg selfMsg -> selfMsg -> state -> Task Never state)
    -> RawScheduler.ProcessId (ReceivedData appMsg selfMsg)
instantiateEffectManager sendToAppFunc (Task init) onEffects onSelfMsg =
    let
        receiver msg stateRes =
            let
                (Task task) =
                    case stateRes of
                        Ok state ->
                            case msg of
                                Self value ->
                                    onSelfMsg router value state

                                App cmds subs ->
                                    onEffects router cmds subs state

                        Err e ->
                            never e
            in
            RawScheduler.andThen
                (\res ->
                    case res of
                        Ok val ->
                            RawScheduler.andThen
                                (\() -> RawScheduler.Value (Ok val))
                                (RawScheduler.sleep 0)

                        Err e ->
                            never e
                )
                task

        selfProcessInitRoot =
            RawScheduler.andThen
                (\() -> init)
                (RawScheduler.sleep 0)

        selfProcessId =
            RawScheduler.newProcessId ()

        router =
            Router
                { sendToApp = \appMsg -> sendToAppFunc appMsg AsyncUpdate
                , selfProcess = selfProcessId
                }
    in
    RawScheduler.rawSpawn receiver selfProcessInitRoot selfProcessId


type alias SendToApp msg =
    msg -> UpdateMetadata -> ()


type alias StepperBuilder model msg =
    SendToApp msg -> model -> SendToApp msg


type alias DebugMetadata =
    EncodeValue


{-| AsyncUpdate is default I think

TODO(harry) understand this by reading source of VirtualDom

-}
type UpdateMetadata
    = SyncUpdate
    | AsyncUpdate


type OtherManagers appMsg
    = OtherManagers (Dict String (RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg)))


type ReceivedData appMsg selfMsg
    = Self selfMsg
    | App (List (HiddenMyCmd appMsg)) (List (HiddenMySub appMsg))


type OutgoingPort
    = OutgoingPort
        { subscribe : EncodeValue -> ()
        , unsubscribe : EncodeValue -> ()
        }


type IncomingPort
    = IncomingPort
        { send : EncodeValue -> ()
        }


type HiddenTypeA
    = HiddenTypeA Never


type HiddenTypeB
    = HiddenTypeB Never


type HiddenMyCmd msg
    = HiddenMyCmd (Bag.LeafType msg)


type HiddenMySub msg
    = HiddenMySub (Bag.LeafType msg)


type HiddenSelfMsg
    = HiddenSelfMsg HiddenSelfMsg


type HiddenState
    = HiddenState HiddenState


type RawJsObject record
    = JsRecord (RawJsObject record)
    | JsAny


type alias Impl flags model msg =
    { init : flags -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    }


type alias InitFunctions model appMsg =
    { stepperBuilder : SendToApp appMsg -> model -> SendToApp appMsg
    , setupOutgoingPort : (EncodeValue -> ()) -> RawScheduler.ProcessId (ReceivedData Never Never)
    , setupIncomingPort :
        SendToApp appMsg
        -> (List (HiddenMySub appMsg) -> ())
        -> ( RawScheduler.ProcessId (ReceivedData appMsg Never), EncodeValue -> List (HiddenMySub appMsg) -> () )
    , setupEffects :
        SendToApp appMsg
        -> Task Never HiddenState
        -> (Router appMsg HiddenSelfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> HiddenState -> Task Never HiddenState)
        -> (Router appMsg HiddenSelfMsg -> HiddenSelfMsg -> HiddenState -> Task Never HiddenState)
        -> RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg)
    , dispatchEffects :
        Cmd appMsg
        -> Sub appMsg
        -> Bag.EffectManagerName
        -> RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg)
        -> ()
    }



-- kernel --


initialize :
    Decoder flags
    -> RawJsObject { args : Maybe (RawJsObject flags) }
    -> Impl flags model msg
    -> InitFunctions model msg
    ->
        RawJsObject
            { ports :
                RawJsObject
                    { outgoingPortName : OutgoingPort
                    , incomingPortName : IncomingPort
                    }
            }
initialize =
    Elm.Kernel.Platform.initialize


makeProgramCallable : Program flags model msg -> Program flags model msg
makeProgramCallable (Program program) =
    Elm.Kernel.Basics.fudgeType program


effectManagerNameToString : Bag.EffectManagerName -> String
effectManagerNameToString =
    Elm.Kernel.Platform.effectManagerNameToString


unwrapCmd : Cmd a -> Bag.EffectBag a
unwrapCmd =
    Elm.Kernel.Basics.unwrapTypeWrapper


unwrapSub : Sub a -> Bag.EffectBag a
unwrapSub =
    Elm.Kernel.Basics.unwrapTypeWrapper


createHiddenMyCmdList : List (Bag.LeafType msg) -> List (HiddenMyCmd msg)
createHiddenMyCmdList =
    Elm.Kernel.Basics.fudgeType


createHiddenMySubList : List (Bag.LeafType msg) -> List (HiddenMySub msg)
createHiddenMySubList =
    Elm.Kernel.Basics.fudgeType


createValuesToSendOutOfPorts : List (HiddenMyCmd Never) -> List EncodeValue
createValuesToSendOutOfPorts =
    Elm.Kernel.Basics.fudgeType


createIncomingPortConverters : List (HiddenMySub msg) -> List (EncodeValue -> msg)
createIncomingPortConverters =
    Elm.Kernel.Basics.fudgeType
