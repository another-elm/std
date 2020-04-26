module Platform.Raw.Task exposing (DoneCallback, Task(..), TryAbortAction, andThen, execImpure, map, sleep)

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
    | AsyncAction (Impure.Function (DoneCallback val) TryAbortAction)


type alias DoneCallback val =
    Impure.Function (Task val) ()


type alias TryAbortAction =
    Impure.Function () ()


andThen : (a -> Task b) -> Task a -> Task b
andThen func task =
    case task of
        Value val ->
            func val

        AsyncAction doEffect ->
            AsyncAction
                (Impure.xx2
                    doEffect
                    (\doneCallback -> Impure.xx2 doneCallback (andThen func))
                )


{-| Create a task that executes a non pure function
-}
execImpure : Impure.Function () a -> Task a
execImpure func =
    AsyncAction
        (Impure.xx42
            (\doneCallback ->
                Impure.function
                    (\() ->
                        let
                            () =
                                func
                                    |> Impure.map Value
                                    |> Impure.andThen doneCallback
                        in
                        Impure.function (\() -> ())
                    )
            )
        )


map : (a -> b) -> Task a -> Task b
map func =
    andThen (\x -> Value (func x))


{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Task ()
sleep time =
    AsyncAction (delay time (Value ()))


delay : Float -> Task val -> Impure.Function (DoneCallback val) TryAbortAction
delay =
    Elm.Kernel.Scheduler.delay
