module Platform.Raw.Channel exposing (Receiver, recv)

import Basics exposing (..)
import Debug
import Elm.Kernel.Channel
import Maybe exposing (Maybe(..))
import Platform.Raw.Impure as Impure
import Platform.Raw.Scheduler as RawScheduler
import Platform.Raw.Task as RawTask
import Tuple


type Receiver msg
    = Receiver


{-| -}
recv : (msg -> RawTask.Task err val) -> Receiver msg -> RawTask.Task err val
recv tagger chl =
    RawTask.AsyncAction
        { then_ =
            \doneCallback ->
                let
                    onMsg : msg -> Impure.Action ()
                    onMsg msg =
                        doneCallback (tagger msg)
                in
                Impure.fromFunction (rawRecv chl) (Impure.toFunction onMsg)
        }


rawRecv : Receiver msg -> Impure.Function (Impure.Function msg ()) RawTask.TryAbortAction
rawRecv =
    Elm.Kernel.Channel.rawRecv
