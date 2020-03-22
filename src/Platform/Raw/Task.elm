module Platform.Raw.Task exposing (DoneCallback, Task(..), TryAbortAction, andThen, execImpure, map, sleep)

{-| This module contains the low level logic for tasks. A
`Task` is a sequence of actions (either syncronous or asyncronous) that will be
run in order by the runtime.
-}

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))


type Task val
    = Value val
    | AsyncAction (DoneCallback val -> TryAbortAction)


type alias DoneCallback val =
    Task val -> ()


type alias TryAbortAction =
    () -> ()


andThen : (a -> Task b) -> Task a -> Task b
andThen func task =
    case task of
        Value val ->
            func val

        AsyncAction doEffect ->
            AsyncAction
                (\doneCallback ->
                    doEffect
                        (\newTask -> doneCallback (andThen func newTask))
                )


{-| Create a task that executes a non pure function
-}
execImpure : (() -> a) -> Task a
execImpure func =
    AsyncAction
        (\doneCallback ->
            let
                () =
                    doneCallback (Value (func ()))
            in
            \() -> ()
        )


map : (a -> b) -> Task a -> Task b
map func =
    andThen (\x -> Value (func x))


{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Task ()
sleep time =
    AsyncAction (delay time (Value ()))


delay : Float -> Task val -> DoneCallback val -> TryAbortAction
delay =
    Elm.Kernel.Scheduler.delay
