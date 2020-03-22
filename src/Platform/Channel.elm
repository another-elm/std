module Platform.Channel exposing (Receiver, Sender, mapSender, recv, send, unbounded)

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))
import Platform
import Platform.Raw.Channel as RawChannel
import Platform.Raw.Task as RawTask
import Platform.Scheduler as Scheduler
import Result exposing (Result(..))


type alias Sender msg =
    RawChannel.Sender msg


type alias Receiver msg =
    RawChannel.Receiver msg


{-| -}
recv : (msg -> Platform.Task Never a) -> Receiver msg -> Platform.Task Never a
recv tagger chl =
    Scheduler.wrapTask (RawChannel.recv (\msg -> Scheduler.unwrapTask (tagger msg)) chl)


{-| Create a task, if run, will send a message to a channel.
-}
send : Sender msg -> msg -> Platform.Task never ()
send channelId msg =
    Scheduler.wrapTask (RawTask.map Ok (RawChannel.send channelId msg))


unbounded : () -> Platform.Task never ( Sender msg, Receiver msg )
unbounded () =
    Scheduler.wrapTask (RawTask.map Ok (RawChannel.unbounded ()))


mapSender : (b -> a) -> Sender a -> Sender b
mapSender =
    RawChannel.mapSender
