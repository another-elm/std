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
import Platform.Raw.Effect as Effect
import Platform.Raw.Impure as Impure
import Platform.Raw.Scheduler as RawScheduler
import Platform.Raw.Task as RawTask
import Platform.Sub exposing (Sub)
import Result exposing (Result(..))
import String exposing (String)
import Tuple



-- PROGRAMS


{-| A `Program` describes an Elm program! How does it react to input? Does it
show anything on screen? Etc.
-}
type Program flags model msg
    = Program


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
                args
                (mainLoop flagsDecoder impl)
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

The channel who's sender we return is a runtime specific channel, kernel code
will send Sub's to this channel.

Each command is a `Platform.Task Never (Maybe msg)`. If the Task resolves with
`Just something` we must send that `something` to the app.

Each sub is a tuple `( RawSub.Id, RawSub.HiddenConvertedSubType -> Maybe msg )`
we can collect these id's and functions and pass them to `resetSubscriptions`.

-}
dispatchCmd : Effect.Runtime msg -> Cmd appMsg -> Impure.Action ()
dispatchCmd runtime cmds =
    let
        runtimeId =
            Effect.getId runtime

        processCmdTask (Task t) =
            t
                |> RawTask.map unwrapResult
                |> RawTask.andThen
                    (\maybeMsg ->
                        case maybeMsg of
                            Just msg ->
                                RawTask.execImpure
                                    (Impure.fromFunction (sendToApp2 runtime) ( msg, AsyncUpdate ))

                            Nothing ->
                                RawTask.Value ()
                    )

        cmdAction : Impure.Action RawScheduler.ProcessId
        cmdAction =
            cmds
                |> unwrapCmd
                |> List.map (\getTaskFromId -> processCmdTask (getTaskFromId runtimeId))
                |> List.map RawScheduler.spawn
                |> List.foldr
                    (\curr accTask ->
                        Impure.andThen
                            (\acc ->
                                Impure.map
                                    (\id -> id :: acc)
                                    curr
                            )
                            accTask
                    )
                    (Impure.resolve [])
                |> Impure.andThen RawScheduler.batch
    in
    cmdAction
        |> Impure.map (\_ -> ())


mainLoop : Decoder flags -> Impl flags model msg -> Impure.Function (MainLoopArgs msg) ()
mainLoop decoder impl =
    Impure.toFunction
        (\{ receiver, encodedFlags, runtime } ->
            let
                flags =
                    case Json.Decode.decodeValue decoder encodedFlags of
                        Ok f ->
                            f

                        Err e ->
                            invalidFlags (Json.Decode.errorToString e)

                stepperBuilder =
                    effectsStepperBuilder impl.subscriptions

                ( initialModel, initialCmd ) =
                    impl.init flags

                dispatcher cmd =
                    RawTask.andThen
                        (\() -> RawTask.execImpure (dispatchCmd runtime cmd))
                        (RawTask.sleep 0)

                receiveMsg : Stepper model -> model -> ( msg, UpdateMetadata ) -> Impure.Action model
                receiveMsg stepper oldModel ( message, meta ) =
                    let
                        ( newModel, newCmd ) =
                            impl.update message oldModel
                    in
                    dispatchCmd runtime newCmd
                        |> Impure.andThen (\() -> Impure.fromFunction (stepper newModel) meta)
                        |> Impure.map (\() -> newModel)

                loop stepper model =
                    receiver
                        |> Channel.recv (receiveMsg stepper model >> RawTask.execImpure)
                        |> RawTask.andThen (loop stepper)
            in
            Impure.fromFunction (stepperBuilder runtime) initialModel
                |> RawTask.execImpure
                |> RawTask.andThen
                    (\stepper ->
                        RawTask.andThen (\() -> loop stepper initialModel) (dispatcher initialCmd)
                    )
                |> RawScheduler.spawn
                |> Impure.map assertProcessId
        )


updateSubListeners : Sub appMsg -> Impure.Function (Effect.Runtime msg) ()
updateSubListeners subBag =
    Impure.toFunction
        (\runtime ->
            subBag
                |> unwrapSub
                |> List.map
                    (Tuple.mapSecond
                        (\tagger v ->
                            case tagger v of
                                Just msg ->
                                    sendToAppAction runtime ( msg, AsyncUpdate )

                                Nothing ->
                                    Impure.resolve ()
                        )
                    )
                |> resetSubscriptionsAction runtime
        )


valueStoreHelper : Task Never state -> (state -> Task Never ( x, state )) -> ( Task Never x, Task Never state )
valueStoreHelper (Task oldTask) stepper =
    let
        newTask =
            RawTask.andThen
                (\res ->
                    let
                        (Task task) =
                            stepper (unwrapResult res)
                    in
                    task
                )
                oldTask

        outputTask =
            RawTask.map (unwrapResult >> Tuple.first >> Ok) newTask

        stateTask =
            RawTask.map (unwrapResult >> Tuple.second >> Ok) newTask
    in
    ( Task outputTask, Task stateTask )


subListenerHelper : Channel.Receiver (Impure.Function () ()) -> RawTask.Task never
subListenerHelper channel =
    Channel.recv RawTask.execImpure channel
        |> RawTask.andThen (\() -> subListenerHelper channel)


subListenerProcess : Impure.Function (Channel.Receiver (Impure.Function () ())) ()
subListenerProcess =
    Impure.toFunction
        (subListenerHelper
            >> RawScheduler.spawn
            >> Impure.map assertProcessId
        )


sendToAppAction : Effect.Runtime msg -> ( msg, UpdateMetadata ) -> Impure.Action ()
sendToAppAction runtime =
    Impure.fromFunction (sendToApp2 runtime)


resetSubscriptionsAction :
    Effect.Runtime msg
    -> List ( Effect.SubId, Effect.HiddenConvertedSubType -> Impure.Action () )
    -> Impure.Action ()
resetSubscriptionsAction runtime updateList =
    Impure.fromFunction
        (resetSubscriptions runtime)
        (updateList
            |> List.map (Tuple.mapSecond Impure.toFunction)
        )


effectsStepperBuilder : (model -> Sub msg) -> StepperBuilder model msg
effectsStepperBuilder subscriptions runtime =
    Impure.toFunction
        (\initialModel ->
            let
                updateSubAction sub =
                    Impure.fromFunction (updateSubListeners sub)

                stepper model _ =
                    updateSubAction (subscriptions model) runtime
                        |> RawTask.execImpure
                        |> RawScheduler.spawn
                        |> Impure.map assertProcessId
            in
            stepper initialModel AsyncUpdate
                |> Impure.map (\() model -> Impure.toFunction (stepper model))
        )


assertProcessId : RawScheduler.ProcessId -> ()
assertProcessId _ =
    ()


unwrapResult : Result Never a -> a
unwrapResult res =
    case res of
        Ok v ->
            v

        Err err ->
            never err



-- Kernel interop TYPES


{-| Kernel code relies on this this type alias. Must be kept consistant with
code in Elm/Kernel/Platform.js.
-}
type alias InitializeHelperFunctions state x =
    { subListenerProcess : Impure.Function (Channel.Receiver (Impure.Function () ())) ()
    , valueStoreHelper : Task Never state -> (state -> Task Never ( x, state )) -> ( Task Never x, Task Never state )
    }


type alias MainLoopArgs msg =
    { receiver : Channel.Receiver ( msg, UpdateMetadata )
    , encodedFlags : Json.Decode.Value
    , runtime : Effect.Runtime msg
    }


type alias StepperBuilder model appMsg =
    Effect.Runtime appMsg -> Impure.Function model (Stepper model)


type alias Stepper model =
    model -> Impure.Function UpdateMetadata ()


{-| This is the actual type of a Program. This is the value that will be called
by javascript so it **must** be this type.
-}
type alias ActualProgram flags =
    Decoder flags
    -> DebugMetadata
    -> RawJsObject
    -> RawJsObject


type alias ImpureSendToApp msg =
    msg -> Impure.Function UpdateMetadata ()


type alias DebugMetadata =
    Encode.Value


type RawJsObject
    = RawJsObject RawJsObject


{-| AsyncUpdate is default I think

TODO(harry) understand this by reading source of VirtualDom

-}
type UpdateMetadata
    = SyncUpdate
    | AsyncUpdate


type alias Impl flags model msg =
    { init : flags -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    }



-- Kernel interop EXPORTS --


{-| Kernel code relies on this definitions type and on the behaviour of these functions.
-}
initializeHelperFunctions : InitializeHelperFunctions state x
initializeHelperFunctions =
    { subListenerProcess = subListenerProcess
    , valueStoreHelper = valueStoreHelper
    }



-- Kernel interop IMPORTS --


initialize :
    RawJsObject
    -> Impure.Function (MainLoopArgs msg) ()
    -> RawJsObject
initialize =
    Elm.Kernel.Platform.initialize


makeProgram : ActualProgram flags -> Program flags model msg
makeProgram =
    Elm.Kernel.Basics.fudgeType


unwrapCmd : Cmd a -> List (Effect.RuntimeId -> Task Never (Maybe msg))
unwrapCmd =
    Elm.Kernel.Basics.unwrapTypeWrapper


unwrapSub : Sub a -> List ( Effect.SubId, Effect.HiddenConvertedSubType -> Maybe msg )
unwrapSub =
    Elm.Kernel.Basics.unwrapTypeWrapper


resetSubscriptions :
    Effect.Runtime msg
    -> Impure.Function (List ( Effect.SubId, Impure.Function Effect.HiddenConvertedSubType () )) ()
resetSubscriptions =
    Elm.Kernel.Platform.resetSubscriptions


sendToApp2 : Effect.Runtime msg -> Impure.Function ( msg, UpdateMetadata ) ()
sendToApp2 =
    Elm.Kernel.Platform.sendToApp


invalidFlags : String -> never
invalidFlags =
    Elm.Kernel.Platform.invalidFlags
