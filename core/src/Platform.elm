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

Effect managers are dead (long live the effect managers). Conseqently you can
**never** get access to a Router, and thus never call `sendToApp` or
`sendToSelf`. If you do not believe that you can _really_ never do this, have a
look at the definitions. We keep them around for now to keep `elm diff` happy.

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
import Platform.Cmd exposing (Cmd)
import Platform.Raw.Channel as Channel
import Platform.Raw.Impure as Impure
import Platform.Raw.Scheduler as RawScheduler
import Platform.Raw.Sub as RawSub
import Platform.Raw.Task as RawTask
import Platform.Sub exposing (Sub)
import Result exposing (Result(..))
import String exposing (String)
import Tuple
import Debug



-- DEFINTIONS TO BE USED BY KERNEL CODE


{-| Kernel code relies on this this type alias. Must be kept consistant with
code in Elm/Kernel/Platform.js.
-}
type alias InitializeHelperFunctions model appMsg =
    { stepperBuilder : ImpureSendToApp appMsg -> model -> appMsg -> UpdateMetadata -> ()
    , setupEffectsChannel :
        ImpureSendToApp appMsg -> Channel.Sender (AppMsgPayload appMsg)
    , dispatchEffects :
        Cmd appMsg
        -> Sub appMsg
        -> Channel.Sender (AppMsgPayload appMsg)
        -> ( Impure.Function (ImpureSendToApp appMsg) (), RawTask.Task () )
    }


{-| Kernel code relies on this definitions type and on the behaviour of these functions.
-}
initializeHelperFunctions : InitializeHelperFunctions model msg
initializeHelperFunctions =
    { stepperBuilder = \_ _ -> \_ _ -> ()
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
const app = Elm.MyThing.init();
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
    = Router Never


{-| Send the router a message for the main loop of your app. This message will
be handled by the overall `update` function, just like events from `Html`.
-}
sendToApp : Router msg a -> msg -> Task x ()
sendToApp (Router router) =
    never router


{-| Send the router a message for your effect manager. This message will
be routed to the `onSelfMsg` function, where you can update the state of your
effect manager as necessary.

As an example, the effect manager for web sockets

-}
sendToSelf : Router a msg -> msg -> Task x ()
sendToSelf (Router router) =
    never router



-- HELPERS --


{-| Multiple channels at play here and type fudging means the compiler cannot
always help us if we get confused so be careful!

The channel who's sender we return is a runtime specific channel, the thunk
returned by dispatchEffects will use the sender to notify this function that we
have command and/or subscriptions to process.

Each command is a `Platform.Task Never (Maybe msg)`. If the Task resolves with
`Just something` we must send that `something` to the app.

Each sub is a tuple `( RawSub.Id, RawSub.HiddenConvertedSubType -> msg )` we
can collect these id's and functions and pass them to `resetSubscriptions`.

-}
setupEffectsChannel : ImpureSendToApp appMsg -> Channel.Sender (AppMsgPayload appMsg)
setupEffectsChannel sendToApp2 =
    let
        dispatchChannel : Channel.Channel (AppMsgPayload appMsg)
        dispatchChannel =
            Channel.rawUnbounded ()

        receiveMsg : AppMsgPayload appMsg -> RawTask.Task ()
        receiveMsg cmds =
            let
                cmdTask =
                    cmds
                        |> List.map (\(Task t) -> t)
                        |> List.map
                            (RawTask.map
                                (\r ->
                                    case r of
                                        Ok (Just msg) ->
                                            Impure.unwrapFunction (sendToApp2 msg) AsyncUpdate

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
            in
            cmdTask
                |> RawTask.map (\_ -> ())

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
    -> Channel.Sender (AppMsgPayload appMsg)
    -> ( Impure.Function (ImpureSendToApp appMsg) (), RawTask.Task () )
dispatchEffects cmdBag subBag =
    let
        cmds =
            unwrapCmd cmdBag

        subs =
            unwrapSub subBag
    in
    \channel ->
        let
            -- Impure functin that resets and re-registers all subscriptions.
            updateSubs sendToAppFunc =
                let
                    thunks =
                        List.map
                            (\( id, tagger ) ->
                                ( id
                                , (\v -> Impure.fromFunction (sendToAppFunc (tagger v)) AsyncUpdate)
                                )
                            )
                            subs
                in
                resetSubscriptionsAction thunks
        in
        ( Impure.toFunction updateSubs
        , Channel.send
            channel
            cmds
        )


resetSubscriptionsAction : (List ( RawSub.Id, RawSub.HiddenConvertedSubType -> Impure.Action () )) -> Impure.Action ()
resetSubscriptionsAction updateList =
    Impure.fromFunction
        resetSubscriptions
        (List.map (\(id, getAction) -> (id, Impure.toFunction getAction)) updateList)


type alias ImpureSendToApp msg =
    msg -> Impure.Function UpdateMetadata ()


type alias DebugMetadata =
    Encode.Value


{-| AsyncUpdate is default I think

TODO(harry) understand this by reading source of VirtualDom

-}
type UpdateMetadata
    = SyncUpdate
    | AsyncUpdate


type alias AppMsgPayload appMsg =
    List (Task Never (Maybe appMsg))


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


unwrapCmd : Cmd a -> List (Task Never (Maybe msg))
unwrapCmd =
    Elm.Kernel.Basics.unwrapTypeWrapper


unwrapSub : Sub a -> List ( RawSub.Id, RawSub.HiddenConvertedSubType -> msg )
unwrapSub =
    Elm.Kernel.Basics.unwrapTypeWrapper


resetSubscriptions : Impure.Function (List ( RawSub.Id, Impure.Function RawSub.HiddenConvertedSubType () )) ()
resetSubscriptions =
    Elm.Kernel.Platform.resetSubscriptions
