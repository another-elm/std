module Platform.Raw.Task exposing (Future, Task(..), TryAbortAction, andThen, execImpure, map, sleep)

{-| This module contains the low level logic for tasks. A
`Task` is a sequence of actions (either syncronous or asyncronous) that will be
run in order by the runtime.
-}

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))
import Platform.Raw.Impure as Impure


type Task val
    = Value val
    | AsyncAction (Future val)


type alias Future a =
    { then_ : (Task a -> ()) -> TryAbortAction }


type alias TryAbortAction =
    Impure.Action ()


andThen : (a -> Task b) -> Task a -> Task b
andThen func task =
    case task of
        Value val ->
            func val

        AsyncAction fut ->
            AsyncAction
                { then_ =
                    \callback ->
                        fut.then_ (\newTask -> callback (andThen func newTask))
                }


{-| Create a task that executes a non pure function
-}
execImpure : Impure.Action a -> Task a
execImpure action =
    AsyncAction
        { then_ =
            \callback ->
                let
                    () =
                        callback (Value (Impure.unwrapFunction action ()))
                in
                Impure.fromPure ()
        }


map : (a -> b) -> Task a -> Task b
map func =
    andThen (\x -> Value (func x))


{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Task ()
sleep time =
    AsyncAction (delay time (Value ()))


delay : Float -> Task val -> Future val
delay =
    Elm.Kernel.Scheduler.delay
