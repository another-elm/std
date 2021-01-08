module Browser.Internal exposing (..)

import Platform.Raw.Impure as Impure
import Time
import Elm.Kernel.Basics
import Elm.Kernel.Browser

rafTask : Platform.Task never Time.Posix
rafTask =
    AsyncAction
        { then_ = \doneCallback ->
            Impure.fromFunction rawRaf (Impure.toFunction (Time.millisToPosix >> Ok >> Value >> doneCallback))
        }
        |> wrapTask


type RawTask err val
    = Value (Result err val)
    | AsyncAction (Future err val)


type alias Future err val =
    { then_ : (RawTask err val -> Impure.Action ()) -> Impure.Action TryAbortAction }


type alias TryAbortAction =
    Impure.Action ()


{-| Create a task that executes a non pure function
-}
execImpure : Impure.Action a -> Platform.Task never a
execImpure action =
    AsyncAction
        { then_ =
            \callback ->
                action
                    |> Impure.andThen (Ok >> Value >> callback)
                    |> Impure.map (\() -> Impure.resolve ())
        }
        |> wrapTask


{-| Create a task that executes a non pure function
-}
fromFunction : Impure.Function a b -> a -> Platform.Task never b
fromFunction func arg =
    execImpure (Impure.fromFunction func arg)


wrapTask : RawTask e o -> Platform.Task e o
wrapTask =
    Elm.Kernel.Basics.fudgeType


unwrapTask : Platform.Task e o -> RawTask e o
unwrapTask =
    Elm.Kernel.Basics.fudgeType


rawRaf : Impure.Function (Impure.Function Int ()) TryAbortAction
rawRaf =
    Elm.Kernel.Browser.rawRaf
