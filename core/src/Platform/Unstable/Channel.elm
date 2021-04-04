module Platform.Unstable.Channel exposing (Receiver, recv)

import Basics exposing (..)
import Elm.Kernel.Channel
import Maybe exposing (Maybe(..))
import Platform.Unstable.Impure as Impure
import Platform.Unstable.Task as RawTask
import Result exposing (Result(..))


type Receiver msg
    = Receiver


{-| -}
recv : Receiver msg -> RawTask.Task never msg
recv chl =
    RawTask.AsyncAction
        { then_ =
            \doneCallback ->
                let
                    onMsg : msg -> Impure.Action ()
                    onMsg msg =
                        doneCallback (msg |> Ok |> RawTask.Value)
                in
                Impure.fromFunction (rawRecv chl) (Impure.toFunction onMsg)
        }


rawRecv : Receiver msg -> Impure.Function (Impure.Function msg ()) RawTask.TryAbortAction
rawRecv =
    Elm.Kernel.Channel.rawRecv
