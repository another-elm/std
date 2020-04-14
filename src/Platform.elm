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
import Platform.Raw.Channel as Channel
import Platform.Raw.Scheduler as RawScheduler
import Platform.Raw.Task as RawTask
import Platform.Sub exposing (Sub)
import Result exposing (Result(..))
import String exposing (String)
import Tuple



-- DEFINTIONS TO BE USED BY KERNEL CODE


{-| Kernel code relies on this this type alias. Must be kept consistant with
code in Elm/Kernel/Platform.js.
-}
type alias InitializeHelperFunctions model appMsg =
    { stepperBuilder : SendToApp appMsg -> model -> SendToApp appMsg
    , setupEffectsChannel :
        SendToApp appMsg -> Channel.Sender (AppMsgPayload appMsg)
    , setupEffects :
        SendToApp appMsg
        -> Channel.Receiver (AppMsgPayload appMsg)
        -> Task Never HiddenState
        -> (Router appMsg HiddenSelfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> HiddenState -> Task Never HiddenState)
        -> (Router appMsg HiddenSelfMsg -> HiddenSelfMsg -> HiddenState -> Task Never HiddenState)
        -> RawTask.Task Never
    , dispatchEffects :
        Cmd appMsg
        -> Sub appMsg
        -> Bag.EffectManagerName
        -> Channel.Sender (AppMsgPayload appMsg)
        -> RawTask.Task ()
    }


{-| Kernel code relies on this definitions type and on the behaviour of these functions.
-}
initializeHelperFunctions : InitializeHelperFunctions model msg
initializeHelperFunctions =
    { stepperBuilder = \_ _ -> \_ _ -> ()
    , setupEffects = setupEffects
    , dispatchEffects = dispatchEffects
    , setupEffectsChannel = setupEffectsChannel
    }



-- PROGRAMS


{-| A `Program` describes an Elm program! How does it react to input? Does it
show anything on screen? Etc.
-}
type Program flags model msg
    = Program


{-| This is the actual type of a Program. This is the value that will be called
by javascript so it **must** be this type.
-}
type alias ActualProgram flags =
    Decoder flags
    -> DebugMetadata
    -> RawJsObject
    -> RawJsObject


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
    makeProgram
        (\flagsDecoder _ args ->
            initialize
                flagsDecoder
                args
                impl
        )



-- TASKS and PROCESSES


{-| Head over to the documentation for the [`Task`](Task) module for more
information on this. It is only defined here because it is a platform
primitive.
-}
type Task err ok
    = Task (RawTask.Task (Result err ok))


{-| Head over to the documentation for the [`Process`](Process) module for
information on this. It is only defined here because it is a platform
primitive.
-}
type ProcessId
    = ProcessId RawScheduler.ProcessId



-- EFFECT MANAGER INTERNALS


{-| An effect manager has access to a “router” that routes messages between
the main app and your individual effect manager.
-}
type Router appMsg selfMsg
    = Router
        { sendToApp : appMsg -> ()
        , selfSender : selfMsg -> RawTask.Task ()
        }


{-| Send the router a message for the main loop of your app. This message will
be handled by the overall `update` function, just like events from `Html`.
-}
sendToApp : Router msg a -> msg -> Task x ()
sendToApp (Router router) msg =
    Task (RawTask.execImpure (\() -> Ok (router.sendToApp msg)))


{-| Send the router a message for your effect manager. This message will
be routed to the `onSelfMsg` function, where you can update the state of your
effect manager as necessary.

As an example, the effect manager for web sockets

-}
sendToSelf : Router a msg -> msg -> Task x ()
sendToSelf (Router router) msg =
    wrapTask (router.selfSender msg)



-- HELPERS --


{-| Multiple channels at play here and type fudging means the compiler cannot
always help us if we get confused so be careful!

The channel who's sender we return is a runtime specific channel, the thunk
returned by dispatchEffects will use the sender to notify this function that we
have command and/or subscriptions to process.

Each command is a `Platform.Task Never (Maybe msg)`. If the Task resolves with
`Just something` we must send that `something` to the app.

Each sub is a tuple `( IncomingPortId, HiddenConvertedSubType -> msg )` we can
collect these id's and functions and pass them to `resetSubscriptions`.

-}
setupEffectsChannel : SendToApp appMsg -> Channel.Sender (AppMsgPayload appMsg)
setupEffectsChannel sendToApp2 =
    let
        dispatchChannel : Channel.Channel (AppMsgPayload appMsg)
        dispatchChannel =
            Channel.rawUnbounded ()

        receiveMsg : AppMsgPayload appMsg -> RawTask.Task ()
        receiveMsg ( cmds, subs ) =
            let
                cmdTask =
                    cmds
                        |> List.map createPlatformEffectFuncsFromCmd
                        |> List.map (\(Task t) -> t)
                        |> List.map
                            (RawTask.map
                                (\r ->
                                    case r of
                                        Ok (Just msg) ->
                                            sendToApp2 msg AsyncUpdate

                                        Ok Nothing ->
                                            ()

                                        Err err ->
                                            never err
                                )
                            )
                        |> List.map RawScheduler.spawn
                        |> List.foldr
                            (\curr accTask ->
                                RawTask.andThen
                                    (\acc ->
                                        RawTask.map
                                            (\id -> id :: acc)
                                            curr
                                    )
                                    accTask
                            )
                            (RawTask.Value [])
                        |> RawTask.andThen RawScheduler.batch

                -- Reset and re-register all subscriptions.
                subTask =
                    subs
                        |> List.map createPlatformEffectFuncsFromSub
                        |> List.map
                            (\( id, tagger ) ->
                                ( id, \v -> sendToApp2 (tagger v) AsyncUpdate )
                            )
                        |> resetSubscriptions
            in
            cmdTask
                |> RawTask.andThen (\_ -> subTask)

        dispatchTask : () -> RawTask.Task ()
        dispatchTask () =
            Tuple.second dispatchChannel
                |> Channel.recv receiveMsg
                |> RawTask.andThen dispatchTask

        _ =
            RawScheduler.rawSpawn (RawTask.andThen dispatchTask (RawTask.sleep 0))
    in
    Tuple.first dispatchChannel


dispatchEffects :
    Cmd appMsg
    -> Sub appMsg
    -> Bag.EffectManagerName
    -> Channel.Sender (AppMsgPayload appMsg)
    -> RawTask.Task ()
dispatchEffects cmdBag subBag =
    let
        effectsDict =
            Dict.empty
                |> gatherCmds cmdBag
                |> gatherSubs subBag
    in
    \key channel ->
        let
            ( cmdList, subList ) =
                Maybe.withDefault
                    ( [], [] )
                    (Dict.get (effectManagerNameToString key) effectsDict)
        in
        Channel.send
            channel
            ( createHiddenMyCmdList cmdList, createHiddenMySubList subList )


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
    -> Channel.Receiver (AppMsgPayload appMsg)
    -> Task Never state
    -> (Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> Task Never state)
    -> (Router appMsg selfMsg -> selfMsg -> state -> Task Never state)
    -> RawTask.Task Never
setupEffects sendToAppFunc receiver init onEffects onSelfMsg =
    instantiateEffectManager
        sendToAppFunc
        receiver
        (unwrapTask init)
        (\router cmds subs state -> unwrapTask (onEffects router cmds subs state))
        (\router selfMsg state -> unwrapTask (onSelfMsg router selfMsg state))


instantiateEffectManager :
    SendToApp appMsg
    -> Channel.Receiver (AppMsgPayload appMsg)
    -> RawTask.Task state
    -> (Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> RawTask.Task state)
    -> (Router appMsg selfMsg -> selfMsg -> state -> RawTask.Task state)
    -> RawTask.Task Never
instantiateEffectManager sendToAppFunc appReceiver init onEffects onSelfMsg =
    Channel.unbounded
        |> RawTask.andThen (instantiateEffectManagerWithSelfChannel sendToAppFunc appReceiver init onEffects onSelfMsg)


instantiateEffectManagerWithSelfChannel :
    SendToApp appMsg
    -> Channel.Receiver (AppMsgPayload appMsg)
    -> RawTask.Task state
    -> (Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> RawTask.Task state)
    -> (Router appMsg selfMsg -> selfMsg -> state -> RawTask.Task state)
    -> Channel.Channel (ReceivedData appMsg selfMsg)
    -> RawTask.Task Never
instantiateEffectManagerWithSelfChannel sendToAppFunc appReceiver init onEffects onSelfMsg ( selfSender, selfReceiver ) =
    let
        receiveMsg :
            state
            -> ReceivedData appMsg selfMsg
            -> RawTask.Task never
        receiveMsg state msg =
            let
                task : RawTask.Task state
                task =
                    case msg of
                        Self value ->
                            onSelfMsg (Router router) value state

                        App ( cmds, subs ) ->
                            onEffects (Router router) cmds subs state
            in
            task
                |> RawTask.andThen
                    (\val ->
                        RawTask.map
                            (\() -> val)
                            (RawTask.sleep 0)
                    )
                |> RawTask.andThen (\newState -> Channel.recv (receiveMsg newState) selfReceiver)

        initTask : RawTask.Task never
        initTask =
            RawTask.sleep 0
                |> RawTask.andThen (\_ -> init)
                |> RawTask.andThen (\state -> Channel.recv (receiveMsg state) selfReceiver)

        forwardAppMessagesTask () =
            Channel.recv
                (\payload -> Channel.send selfSender (App payload))
                appReceiver
                |> RawTask.andThen forwardAppMessagesTask

        router =
            { sendToApp = \appMsg -> sendToAppFunc appMsg AsyncUpdate
            , selfSender = \msg -> Channel.send selfSender (Self msg)
            }
    in
    RawScheduler.spawn (forwardAppMessagesTask ())
        |> RawTask.andThen (\_ -> initTask)


unwrapTask : Task Never a -> RawTask.Task a
unwrapTask (Task task) =
    RawTask.map
        (\res ->
            case res of
                Ok val ->
                    val

                Err x ->
                    never x
        )
        task


wrapTask : RawTask.Task a -> Task never a
wrapTask task =
    Task (RawTask.map Ok task)


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


type IncomingPortId
    = IncomingPortId IncomingPortId


type HiddenConvertedSubType
    = HiddenConvertedSubType HiddenConvertedSubType


type ReceivedData appMsg selfMsg
    = Self selfMsg
    | App (AppMsgPayload appMsg)


type alias AppMsgPayload appMsg =
    ( List (HiddenMyCmd appMsg), List (HiddenMySub appMsg) )


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



-- kernel --


initialize :
    Decoder flags
    -> RawJsObject
    -> Impl flags model msg
    -> RawJsObject
initialize =
    Elm.Kernel.Platform.initialize


makeProgram : ActualProgram flags -> Program flags model msg
makeProgram =
    Elm.Kernel.Basics.fudgeType


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


createIncomingPortConverters : List (HiddenMySub msg) -> List (Encode.Value -> msg)
createIncomingPortConverters =
    Elm.Kernel.Basics.fudgeType


createPlatformEffectFuncsFromCmd : HiddenMyCmd msg -> Task Never (Maybe msg)
createPlatformEffectFuncsFromCmd =
    Elm.Kernel.Basics.fudgeType


createPlatformEffectFuncsFromSub : HiddenMySub msg -> ( IncomingPortId, HiddenConvertedSubType -> msg )
createPlatformEffectFuncsFromSub =
    Elm.Kernel.Basics.fudgeType


resetSubscriptions : List ( IncomingPortId, HiddenConvertedSubType -> () ) -> RawTask.Task ()
resetSubscriptions =
    Elm.Kernel.Platform.resetSubscriptions
