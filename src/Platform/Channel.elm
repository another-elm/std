module Platform.Channel exposing (recv, Channel, channel, rawSend, send)


import Basics exposing (..)
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))
import Debug

import Platform.RawScheduler as RawScheduler


type Channel msg
    = Channel {}


{-|
-}
recv : (msg -> RawScheduler.Task a) -> Channel msg -> RawScheduler.Task  a
recv tagger chl =
    let
        innerDoneCallback : RawScheduler.DoneCallback a -> RawScheduler.Task msg -> ()
        innerDoneCallback doneCallback newTask =
            doneCallback (RawScheduler.andThen (\msg -> tagger msg) newTask)
    in

    RawScheduler.AsyncAction
        (\doneCallback ->
            rawRecv
                chl
                (innerDoneCallback doneCallback)
        )


{-| NON PURE!

Send a message to a process (adds the message to the processes mailbox) and
**enqueue** that process.

If the process is "ready" it will then act upon the next message in its
mailbox.

-}
rawSend : Channel msg -> ()
rawSend channelId =
    let
        _ =
            mailboxAdd msg processId
    in
    enqueue processId


{-| Create a task, if run, will make the process deal with a message.
-}
send : ProcessId msg -> msg -> Task ()
send processId msg =
    SyncAction
        (\() ->
            let
                (ProcessId _) =
                    rawSend processId msg
            in
            Value ()
        )

channel : () -> Channel msg
channel () =
    Channel {}

rawRecv : Channel msg -> RawScheduler.DoneCallback msg -> RawScheduler.TryAbortAction
rawRecv =
    Elm.Kernel.Scheduler.rawRecv
