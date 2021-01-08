module Platform.Raw.Task exposing (Future, Task(..), TryAbortAction, andThen, execImpure, map, noopAbort, sleep)

{-| This module contains the low level logic for tasks. A
`Task` is a sequence of actions (either syncronous or asyncronous) that will be
run in order by the runtime.
-}

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))
import Platform.Raw.Impure as Impure
import Result exposing (Result(..))


type Task err val
    = Value (Result err val)
    | AsyncAction (Future err val)


type alias Future err val =
    { then_ : (Task err val -> Impure.Action ()) -> Impure.Action TryAbortAction }


type alias TryAbortAction =
    Impure.Action ()


noopAbort : TryAbortAction
noopAbort =
    Impure.resolve ()


andThen : (Result e1 a1 -> Task e2 a2) -> Task e1 a1 -> Task e2 a2
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
execImpure : Impure.Action a -> Task never a
execImpure action =
    AsyncAction
        { then_ =
            \callback ->
                action
                    |> Impure.andThen (Ok >> Value >> callback)
                    |> Impure.map (\() -> noopAbort)
        }


syncBinding : Impure.Function () (Task never a) -> Task never a
syncBinding a =
    execImpure a
        |> andThen
            (\res ->
                case res of
                    Ok t ->
                        t

                    Err e ->
                        never e
            )


map : (Result e1 a1 -> Result e2 a2) -> Task e1 a1 -> Task e2 a2
map func =
    andThen (\x -> Value (func x))


{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Task never ()
sleep time =
    AsyncAction (delay time (Value (Ok ())))


delay : Float -> Task err val -> Future err val
delay =
    Elm.Kernel.Scheduler.delay
