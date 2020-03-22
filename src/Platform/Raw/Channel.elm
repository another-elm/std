module Platform.Raw.Channel exposing (Receiver, Sender, mapSender, rawSend, rawUnbounded, recv, send, unbounded)

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))
import Platform.Raw.Scheduler as RawScheduler
import Platform.Raw.Task as RawTask
import Tuple


type Sender msg
    = Sender (msg -> ())


type Receiver msg
    = Receiver


{-| -}
recv : (msg -> RawTask.Task a) -> Receiver msg -> RawTask.Task a
recv tagger chl =
    RawTask.AsyncAction
        (\doneCallback ->
            rawRecv chl (\msg -> doneCallback (tagger msg))
        )


{-| NON PURE!

Send a message to a channel. If there are tasks waiting for a message then one
will complete during this function call. If there are no tasks waiting the
message will be added to the channel's queue.

-}
rawSend : Sender msg -> msg -> ()
rawSend (Sender sender) =
    sender


{-| Create a task, if run, will send a message to a channel.
-}
send : Sender msg -> msg -> RawTask.Task ()
send channelId msg =
    RawTask.execImpure (\() -> rawSend channelId msg)


rawUnbounded : () -> ( Sender msg, Receiver msg )
rawUnbounded () =
    Elm.Kernel.Scheduler.rawUnbounded ()
        |> Tuple.mapFirst Sender


unbounded : () -> RawTask.Task ( Sender msg, Receiver msg )
unbounded () =
    RawTask.execImpure rawUnbounded


rawRecv : Receiver msg -> (msg -> ()) -> RawTask.TryAbortAction
rawRecv =
    Elm.Kernel.Scheduler.rawRecv


mapSender : (b -> a) -> Sender a -> Sender b
mapSender fn (Sender sender) =
    Sender (\b -> sender (fn b))


rawUnboundedKernel : () -> ( msg -> (), Receiver msg )
rawUnboundedKernel =
    Elm.Kernel.Scheduler.rawUnbounded
