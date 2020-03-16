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

import Basics exposing (..)
import Dict exposing (Dict)
import Elm.Kernel.Basics
import Elm.Kernel.Platform
import Json.Decode exposing (Decoder)
import Json.Encode as Encode
import List exposing ((::))
import Maybe exposing (Maybe(..))
import Platform.Bag as Bag
import Platform.Cmd exposing (Cmd)
import Platform.RawScheduler as RawScheduler
import Platform.Sub exposing (Sub)
import Result exposing (Result(..))
import String exposing (String)




-- PROGRAMS


{-| A `Program` describes an Elm program! How does it react to input? Does it
show anything on screen? Etc.
-}
type Program flags model msg
    = Program
        (Decoder flags
         -> DebugMetadata
         -> RawJsObject
         -> RawJsObject
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
                    , setupEffects = setupEffects
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
    = Task (RawScheduler.Task (Result err ok) Never)


{-| Head over to the documentation for the [`Process`](Process) module for
information on this. It is only defined here because it is a platform
primitive.
-}
type ProcessId
    = ProcessId (RawScheduler.ProcessId Never Never)



-- EFFECT MANAGER INTERNALS


{-| An effect manager has access to a “router” that routes messages between
the main app and your individual effect manager.
-}
type Router appMsg selfMsg
    = Router
        { sendToApp : appMsg -> ()
        , selfProcess : RawScheduler.ProcessId (ReceivedData appMsg selfMsg) Never
        }


{-| Send the router a message for the main loop of your app. This message will
be handled by the overall `update` function, just like events from `Html`.
-}
sendToApp : Router msg a -> msg -> Task x ()
sendToApp (Router router) msg =
    Task (RawScheduler.SyncAction (\() -> RawScheduler.Value (Ok (router.sendToApp msg))))


{-| Send the router a message for your effect manager. This message will
be routed to the `onSelfMsg` function, where you can update the state of your
effect manager as necessary.

As an example, the effect manager for web sockets

-}
sendToSelf : Router a msg -> msg -> Task x ()
sendToSelf (Router router) msg =
    Task (RawScheduler.map Ok (RawScheduler.send router.selfProcess (Self msg)))



-- HELPERS --


setupOutgoingPort : (Encode.Value -> ()) -> RawScheduler.ProcessId (ReceivedData Never Never) Never
setupOutgoingPort outgoingPortSend =
    let
        init =
            RawScheduler.Value ()

        onSelfMsg _ selfMsg () =
            never selfMsg

        onEffects :
            Router Never Never
            -> List (HiddenMyCmd Never)
            -> List (HiddenMySub Never)
            -> ()
            -> RawScheduler.Task () Never
        onEffects _ cmdList _ () =
            RawScheduler.execImpure
                (\() ->
                    let
                        _ =
                            cmdList
                                |> createValuesToSendOutOfPorts
                                |> List.map outgoingPortSend
                    in
                    ()
                )
    in
    instantiateEffectManager never init onEffects onSelfMsg


setupIncomingPort :
    SendToApp msg
    -> (List (HiddenMySub msg) -> ())
    -> ( RawScheduler.ProcessId (ReceivedData msg Never) Never, Encode.Value -> List (HiddenMySub msg) -> () )
setupIncomingPort sendToApp2 updateSubs =
    let
        init =
            RawScheduler.Value ()

        onSelfMsg _ selfMsg () =
            never selfMsg

        onEffects _ _ subList () =
            RawScheduler.execImpure (\() -> updateSubs subList)

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
    -> RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg) Never
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


setupEffects :
    SendToApp appMsg
    -> Task Never state
    -> (Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> Task Never state)
    -> (Router appMsg selfMsg -> selfMsg -> state -> Task Never state)
    -> RawScheduler.ProcessId (ReceivedData appMsg selfMsg) Never
setupEffects sendToAppFunc init onEffects onSelfMsg =
    instantiateEffectManager
        sendToAppFunc
        (unwrapTask init)
        (\router cmds subs state -> unwrapTask (onEffects router cmds subs state))
        (\router selfMsg state -> unwrapTask (onSelfMsg router selfMsg state))


instantiateEffectManager :
    SendToApp appMsg
    -> RawScheduler.Task state Never
    -> (Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> RawScheduler.Task state Never)
    -> (Router appMsg selfMsg -> selfMsg -> state -> RawScheduler.Task state Never)
    -> RawScheduler.ProcessId (ReceivedData appMsg selfMsg) Never
instantiateEffectManager sendToAppFunc init onEffects onSelfMsg =
    let
        receiver msg state =
            let
                task =
                    case msg of
                        Self value ->
                            onSelfMsg router value state

                        App cmds subs ->
                            onEffects router cmds subs state
            in
            RawScheduler.andThen
                (\val ->
                    RawScheduler.map
                        (\() -> val)
                        (RawScheduler.sleep 0)
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


unwrapTask : Task Never a -> RawScheduler.Task a Never
unwrapTask (Task task) =
    RawScheduler.map
        (\res ->
            case res of
                Ok val ->
                    val

                Err x ->
                    never x
        )
        task


type alias SendToApp msg =
    msg -> UpdateMetadata -> ()


type alias DebugMetadata =
    Encode.Value


{-| AsyncUpdate is default I think

TODO(harry) understand this by reading source of VirtualDom

-}
type UpdateMetadata
    = SyncUpdate
    | AsyncUpdate


type OtherManagers appMsg
    = OtherManagers (Dict String (RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg) Never))


type ReceivedData appMsg selfMsg
    = Self selfMsg
    | App (List (HiddenMyCmd appMsg)) (List (HiddenMySub appMsg))


type HiddenMyCmd msg
    = HiddenMyCmd (HiddenMyCmd msg)


type HiddenMySub msg
    = HiddenMySub (HiddenMySub msg)


type HiddenSelfMsg
    = HiddenSelfMsg HiddenSelfMsg


type HiddenState
    = HiddenState HiddenState


type RawJsObject
    = RawJsObject RawJsObject


type alias Impl flags model msg =
    { init : flags -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    }


type alias InitFunctions model appMsg =
    { stepperBuilder : SendToApp appMsg -> model -> SendToApp appMsg
    , setupOutgoingPort : (Encode.Value -> ()) -> RawScheduler.ProcessId (ReceivedData Never Never) Never
    , setupIncomingPort :
        SendToApp appMsg
        -> (List (HiddenMySub appMsg) -> ())
        -> ( RawScheduler.ProcessId (ReceivedData appMsg Never) Never, Encode.Value -> List (HiddenMySub appMsg) -> () )
    , setupEffects :
        SendToApp appMsg
        -> Task Never HiddenState
        -> (Router appMsg HiddenSelfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> HiddenState -> Task Never HiddenState)
        -> (Router appMsg HiddenSelfMsg -> HiddenSelfMsg -> HiddenState -> Task Never HiddenState)
        -> RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg) Never
    , dispatchEffects :
        Cmd appMsg
        -> Sub appMsg
        -> Bag.EffectManagerName
        -> RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg) Never
        -> ()
    }



-- kernel --


initialize :
    Decoder flags
    -> RawJsObject
    -> Impl flags model msg
    -> InitFunctions model msg
    -> RawJsObject
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


createValuesToSendOutOfPorts : List (HiddenMyCmd Never) -> List Encode.Value
createValuesToSendOutOfPorts =
    Elm.Kernel.Basics.fudgeType


createIncomingPortConverters : List (HiddenMySub msg) -> List (Encode.Value -> msg)
createIncomingPortConverters =
    Elm.Kernel.Basics.fudgeType
