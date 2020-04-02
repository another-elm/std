module Platform.Raw.Channel exposing (Receiver, Sender, Channel, mapSender, rawSend, rawUnbounded, tryRecv, recv, send, unbounded)

import Basics exposing (..)
import Debug
import Elm.Kernel.Channel
import Maybe exposing (Maybe(..))
import Platform.Raw.Scheduler as RawScheduler
import Platform.Raw.Task as RawTask
import Tuple


type Sender msg
    = Sender


type Receiver msg
    = Receiver


type alias Channel msg =
    ( Sender msg, Receiver msg )

{-| -}
recv : (msg -> RawTask.Task a) -> Receiver msg -> RawTask.Task a
recv tagger chl =
    RawTask.AsyncAction
        (\doneCallback ->
            rawRecv chl (\msg -> doneCallback (tagger msg))
        )


tryRecv : (Maybe msg -> RawTask.Task a) -> Receiver msg -> RawTask.Task a
tryRecv tagger chl =
    RawTask.andThen
        tagger
        (RawTask.execImpure (\() -> rawTryRecv chl))


{-| NON PURE!

Send a message to a channel. If there are tasks waiting for a message then one
will complete during this function call. If there are no tasks waiting the
message will be added to the channel's queue.

-}
rawSend : Sender msg -> msg -> ()
rawSend =
    Elm.Kernel.Channel.rawSend


{-| Create a task, if run, will send a message to a channel.
-}
send : Sender msg -> msg -> RawTask.Task ()
send channelId msg =
    RawTask.execImpure (\() -> rawSend channelId msg)


rawUnbounded : () -> ( Sender msg, Receiver msg )
rawUnbounded =
    Elm.Kernel.Channel.rawUnbounded


unbounded : () -> RawTask.Task ( Sender msg, Receiver msg )
unbounded () =
    RawTask.execImpure rawUnbounded


rawRecv : Receiver msg -> (msg -> ()) -> RawTask.TryAbortAction
rawRecv =
    Elm.Kernel.Channel.rawRecv


rawTryRecv : Receiver msg -> Maybe msg
rawTryRecv =
    Elm.Kernel.Channel.rawTryRecv


mapSender : (b -> a) -> Sender a -> Sender b
mapSender =
    Elm.Kernel.Channel.mapSender
