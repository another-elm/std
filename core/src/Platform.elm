module Platform exposing
    ( Program, program, worker
    , Task, ProcessId
    , Router, sendToApp, sendToSelf
    )

{-|


# Programs

@docs Program, program, worker


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
import Platform.Cmd as Cmd exposing (Cmd)
import Platform.Raw.Channel as Channel
import Platform.Raw.Effect as Effect
import Platform.Raw.Impure as Impure
import Platform.Raw.Scheduler as RawScheduler
import Platform.Raw.Task as RawTask exposing (andThen)
import Platform.Sub as Sub exposing (Sub)
import Result exposing (Result(..))
import String exposing (String)
import Tuple



-- PROGRAMS


{-| A `Program` describes an Elm program! How does it react to input? Does it
show anything on screen? Etc.
-}
type Program flags model msg
    = Program


{-| -}
program :
    StepperBuilder model msg
    ->
        { any
            | init : flags -> Effect.Runtime msg -> ( model, Cmd msg )
            , update : msg -> model -> ( model, Cmd msg )
            , subscriptions : model -> Sub msg
        }
    -> Program flags model msg
program stepperBuilder impl =
    makeProgram
        (\flagsDecoder _ args ->
            initialize
                args
                (Impure.toFunction (mainLoop stepperBuilder flagsDecoder args impl))
        )


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
worker { init, update, subscriptions } =
    program
        nullStepperBuilder
        { init = \flags _ -> init flags
        , update = update
        , subscriptions = subscriptions
        }



-- TASKS and PROCESSES


{-| Head over to the documentation for the [`Task`](Task) module for more
information on this. It is only defined here because it is a platform
primitive.
-}
type Task err ok
    = Stub_Task


{-| Head over to the documentation for the [`Process`](Process) module for
information on this. It is only defined here because it is a platform
primitive.
-}
type ProcessId
    = Stub_ProcessId



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
dispatchCmd : Effect.Runtime msg -> Cmd msg -> Impure.Action ()
dispatchCmd runtime (Cmd.Cmd (Effect.Cmd cmds)) =
    let
        runtimeId =
            Effect.getId runtime

        processCmdTask getTaskFromId =
            getTaskFromId runtimeId
                |> andThenOk
                    (\maybeMsg ->
                        case maybeMsg of
                            Just msg ->
                                RawTask.execImpure (sendToAppAction runtime ( msg, AsyncUpdate ))

                            Nothing ->
                                RawTask.Value (Ok ())
                    )
    in
    cmds
        |> List.map processCmdTask
        |> List.map RawScheduler.spawn
        |> List.foldr
            (\id -> Impure.andThen (\() -> id) >> Impure.map assertProcessId)
            (Impure.resolve ())


mainLoop :
    StepperBuilder model msg
    -> Decoder flags
    -> RawJsObject
    ->
        { any
            | init : flags -> Effect.Runtime msg -> ( model, Cmd msg )
            , update : msg -> model -> ( model, Cmd msg )
            , subscriptions : model -> Sub msg
        }
    -> MainLoopArgs any msg
    -> Impure.Action ()
mainLoop extraStepperBuilder decoder args impl { receiver, encodedFlags, runtime } =
    let
        flags =
            Json.Decode.decodeValue decoder encodedFlags
                |> Result.mapError (Json.Decode.errorToString >> invalidFlags)
                |> assertResultIsOk

        stepperBuilder =
            combineStepperBuilders
                (effectsStepperBuilder impl.subscriptions)
                extraStepperBuilder

        ( initialModel, initialCmd ) =
            impl.init flags runtime

        receiveMsg : Stepper model -> model -> ( msg, UpdateMetadata ) -> Impure.Action model
        receiveMsg stepper oldModel ( message, meta ) =
            let
                ( newModel, newCmd ) =
                    impl.update message oldModel
            in
            dispatchCmd runtime newCmd
                |> Impure.andThen (\() -> stepper newModel meta)
                |> Impure.map (\() -> newModel)

        loop stepper model =
            receiver
                |> Channel.recv (receiveMsg stepper model >> RawTask.execImpure)
                |> andThenOk (loop stepper)
    in
    stepperBuilder runtime args initialModel
        |> RawTask.execImpure
        |> andThenOk
            (\stepper ->
                RawTask.sleep 0
                    |> andThenOk (\() -> RawTask.execImpure (dispatchCmd runtime initialCmd))
                    |> andThenOk (\() -> loop stepper initialModel)
            )
        |> RawScheduler.spawn
        |> Impure.map assertProcessId


updateSubListeners : Sub msg -> Effect.Runtime msg -> Impure.Action ()
updateSubListeners (Sub.Sub (Effect.Sub subBag)) runtime =
    subBag
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


valueStoreHelper :
    RawTask.Task Never state
    -> (state -> RawTask.Task Never ( x, state ))
    -> ( RawTask.Task Never x, RawTask.Task Never state )
valueStoreHelper oldTask stepper =
    let
        newTask =
            andThenOk stepper oldTask

        outputTask =
            mapOk Tuple.first newTask

        stateTask =
            mapOk Tuple.second newTask
    in
    ( outputTask, stateTask )


createCmd : (Effect.RuntimeId -> RawTask.Task Never (Maybe msg)) -> Cmd msg
createCmd createTask =
    Cmd.Cmd (Effect.Cmd [ createTask ])


subscriptionHelper : Effect.SubId -> (Effect.HiddenConvertedSubType -> Maybe msg) -> Sub msg
subscriptionHelper key tagger =
    Sub.Sub (Effect.Sub [ ( key, tagger ) ])


subListenerHelper : Channel.Receiver (Impure.Function () ()) -> RawTask.Task err never
subListenerHelper channel =
    Channel.recv RawTask.execImpure channel
        |> andThenOk (\() -> subListenerHelper channel)


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
effectsStepperBuilder subscriptions runtime _ initialModel =
    let
        stepper model _ =
            updateSubListeners (subscriptions model) runtime
                |> RawTask.execImpure
                |> RawScheduler.spawn
                |> Impure.map assertProcessId
    in
    stepper initialModel AsyncUpdate
        |> Impure.map (\() -> stepper)


assertProcessId : RawScheduler.ProcessId -> ()
assertProcessId _ =
    ()


andThenOk : (a1 -> RawTask.Task e a2) -> RawTask.Task Never a1 -> RawTask.Task e a2
andThenOk func task =
    RawTask.andThen
        (\x ->
            case x of
                Ok val ->
                    func val

                Err n ->
                    never n
        )
        task


mapOk : (a1 -> a2) -> RawTask.Task Never a1 -> RawTask.Task never a2
mapOk func task =
    RawTask.map
        (\x ->
            case x of
                Ok val ->
                    Ok (func val)

                Err n ->
                    never n
        )
        task


assertResultIsOk : Result Never a -> a
assertResultIsOk res =
    case res of
        Ok v ->
            v

        Err err ->
            never err


combineStepperBuilders :
    StepperBuilder model msg
    -> StepperBuilder model msg
    -> StepperBuilder model msg
combineStepperBuilders firstBuilder secondBuilder runtime args initialModel =
    firstBuilder runtime args initialModel
        |> Impure.andThen
            (\firstStepper ->
                secondBuilder runtime args initialModel
                    |> Impure.map
                        (\secondStepper model meta ->
                            firstStepper model meta
                                |> Impure.andThen (\() -> secondStepper model meta)
                        )
            )


{-| Do nothing with initial model and do nothing with subsequent models.
-}
nullStepperBuilder : StepperBuilder model msg
nullStepperBuilder _ _ _ =
    Impure.resolve (\_ _ -> Impure.resolve ())



-- Kernel interop TYPES


{-| Kernel code relies on this this type alias. Must be kept consistant with
code in Elm/Kernel/Platform.js.
-}
type alias InitializeHelperFunctions state x msg =
    { subListenerProcess : Impure.Function (Channel.Receiver (Impure.Function () ())) ()
    , valueStoreHelper :
        RawTask.Task Never state
        -> (state -> RawTask.Task Never ( x, state ))
        -> ( RawTask.Task Never x, RawTask.Task Never state )
    , subscriptionHelper : Effect.SubId -> (Effect.HiddenConvertedSubType -> Maybe msg) -> Sub msg
    , createCmd : (Effect.RuntimeId -> RawTask.Task Never (Maybe msg)) -> Cmd msg
    }


type alias MainLoopArgs a msg =
    { a
        | receiver : Channel.Receiver ( msg, UpdateMetadata )
        , encodedFlags : Json.Decode.Value
        , runtime : Effect.Runtime msg
    }


type alias StepperBuilder model appMsg =
    Effect.Runtime appMsg -> RawJsObject -> model -> Impure.Action (Stepper model)


type alias Stepper model =
    model -> UpdateMetadata -> Impure.Action ()


{-| This is the actual type of a Program. This is the value that will be called
by javascript so it **must** be this type.
-}
type alias ActualProgram flags =
    Decoder flags
    -> DebugMetadata
    -> RawJsObject
    -> RawJsObject


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



-- Kernel interop EXPORTS --


{-| Kernel code relies on this definitions type and on the behaviour of these functions.
-}
initializeHelperFunctions : InitializeHelperFunctions state x msg
initializeHelperFunctions =
    { subListenerProcess = subListenerProcess
    , valueStoreHelper = valueStoreHelper
    , subscriptionHelper = subscriptionHelper
    , createCmd = createCmd
    }



-- Kernel interop IMPORTS --


initialize :
    RawJsObject
    -> Impure.Function (MainLoopArgs any msg) ()
    -> RawJsObject
initialize =
    Elm.Kernel.Platform.initialize


makeProgram : ActualProgram flags -> Program flags model msg
makeProgram =
    Elm.Kernel.Basics.fudgeType


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
