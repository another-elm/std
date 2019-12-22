module Platform.Scheduler exposing (..)

{-|

## Module notes:

TODO(harry) explain need for this module and how it relates to Platform and
  Platform.RawScheduler.

-}

import Platform
import Platform.RawScheduler as RawScheduler
import Result exposing (Result(..))
import Basics exposing (..)


type alias ProcessId msg
  = RawScheduler.ProcessId msg

type alias DoneCallback err ok =
  Platform.Task err ok -> ()


type alias TryAbortAction =
  RawScheduler.TryAbortAction


succeed : ok -> Platform.Task never ok
succeed val =
  Platform.Task (RawScheduler.Value (Ok val))


fail : err -> Platform.Task err never
fail e =
  Platform.Task (RawScheduler.Value (Err e))


binding : (DoneCallback err ok -> TryAbortAction) -> Platform.Task err ok
binding callback =
  Platform.Task
    (RawScheduler.AsyncAction
      (\doneCallback -> callback (\(Platform.Task task) -> doneCallback task))
    )


andThen : (ok1 -> Platform.Task err ok2) -> Platform.Task err ok1 -> Platform.Task err ok2
andThen func (Platform.Task task) =
  Platform.Task
    (RawScheduler.andThen
      (\r ->
        case r of
          Ok val ->
            let
              (Platform.Task rawTask) =
                func val
            in
              rawTask

          Err e ->
            RawScheduler.Value (Err e)
      )
      task
    )


onError : (err1 -> Platform.Task err2 ok) -> Platform.Task err1 ok -> Platform.Task err2 ok
onError func (Platform.Task task) =
  Platform.Task
    (RawScheduler.andThen
      (\r ->
        case r of
          Ok val ->
            RawScheduler.Value (Ok val)

          Err e ->
            let
              (Platform.Task rawTask) =
                func e
            in
              rawTask
      )
      task
    )


{-| Create a task, if run, will make the process deal with a message.
-}
send : ProcessId msg -> msg -> Platform.Task never ()
send proc msg =
  Platform.Task
    (RawScheduler.andThen
      (\() -> RawScheduler.Value (Ok ()))
      (RawScheduler.send proc msg)
    )


{-| Create a task that, when run, will spawn a process.

There is no way to send messages to a process spawned in this way.
-}
spawn : Platform.Task err ok -> Platform.Task never Platform.ProcessId
spawn (Platform.Task task) =
  Platform.Task
    (RawScheduler.andThen
      (\proc -> RawScheduler.Value (Ok (Platform.ProcessId proc)))
      (RawScheduler.spawn (\msg state -> never msg) task)
    )



{-| This is provided to make __Schdeuler_rawSpawn work!

TODO(harry) remove once code in other `elm/*` packages has been updated.
-}
rawSpawn : Platform.Task err ok -> Platform.ProcessId
rawSpawn (Platform.Task task) =
  Platform.ProcessId (RawScheduler.rawSpawn (\msg state -> never msg) task (RawScheduler.newProcessId ()))



{-| Create a task kills a process.
-}
kill : ProcessId Never -> Platform.Task never ()
kill proc =
  Platform.Task
    (RawScheduler.andThen
      (\() -> RawScheduler.Value (Ok ()))
      (RawScheduler.kill proc)
    )


{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Platform.Task x ()
sleep time =
  Platform.Task
    (RawScheduler.andThen
      (\() -> RawScheduler.Value (Ok ()))
      (RawScheduler.sleep time)
    )
