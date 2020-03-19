module Platform.Channel exposing (Channel, createChannel, rawCreateChannel, rawSend, recv, send)

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))
import Platform.RawScheduler as RawScheduler


type Channel msg
    = Channel { id : RawScheduler.UniqueId }


{-| -}
recv : (msg -> RawScheduler.Task a) -> Channel msg -> RawScheduler.Task a
recv tagger chl =
    RawScheduler.AsyncAction
        (\doneCallback ->
            rawRecv chl (\msg -> doneCallback (tagger msg))
        )


{-| NON PURE!

Send a message to a channel. If there are tasks waiting for a message then one
will complete during this function call. If there are no tasks waiting the
message will be added to the channel's queue.

-}
rawSend : Channel msg -> msg -> ()
rawSend =
    Elm.Kernel.Scheduler.rawSend


{-| Create a task, if run, will send a message to a channel.
-}
send : Channel msg -> msg -> RawScheduler.Task ()
send channelId msg =
    RawScheduler.execImpure (\() -> rawSend channelId msg)


rawCreateChannel : () -> Channel msg
rawCreateChannel () =
    registerChannel (Channel { id = RawScheduler.getGuid () })


createChannel : () -> RawScheduler.Task (Channel msg)
createChannel () =
    RawScheduler.execImpure rawCreateChannel


rawRecv : Channel msg -> (msg -> ()) -> RawScheduler.TryAbortAction
rawRecv =
    Elm.Kernel.Scheduler.rawRecv


registerChannel : Channel msg -> Channel msg
registerChannel =
    Elm.Kernel.Scheduler.registerChannel
