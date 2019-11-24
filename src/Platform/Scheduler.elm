module Platform.Scheduler exposing (..)

{-|

## Module notes:

* Types called `HiddenXXX` are used to bypass the elm type system.
    The programmer takes **full responsibiliy** for making sure
    that the types line up.
    That does mean you have to second guess any and all strange
    decisions I have  made, hopefully things will get clearer over
    time.
- The `Binding` constructor on the `Task` type is tricky one.
  + It contains a callback function (that we will call `doEffect`)
    and a `killer` function. `doEffect` will be called by
    `Scheduler.enqueue` and will be passed another callback.
    We call this second callback `doneCallback`.
    `doEffect` should do its effects (which may be impure) and then,
    when it is done, call `doneCallback`.`doEffect` **must** call
    `doneCallback` and it **must** pass `doneCallback` a
    `Task ErrX OkX` as an argument. (I am unsure about the values of
    ErrX and OkX at the moment). The return value of `doEffect` may
    be either `undefined` or a function that cancels the effect.
  + If the second value `killer` is not Nothing, then the runtime
    will call it if the execution of the `Task` should be aborted.



## Differences between this and offical elm/core

* `Process.mailbox` is a (mutable) js array in elm/core and an elm list here.
* `Process.stack` is an (immutable) js linked list in elm/core and an elm list here.
* `Elm.Kernel.Scheduler.rawSend` mutates the process before enqueuing it in elm/core.
    Here we create a **new** process with the **same** (unique) id and then enqueue it.
    Same applies for (non-raw) `send`.

-}

import Platform
import Platform.RawScheduler as RawScheduler
import Result exposing (Result(..))
import Basics exposing (Never)


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
    (RawScheduler.binding
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


{-| Create a task that spawns a processes.
-}
spawn : Platform.Task err ok -> Platform.Task never Platform.ProcessId
spawn (Platform.Task task) =
  Platform.Task
    (RawScheduler.andThen
      (\proc -> RawScheduler.Value (Ok (Platform.ProcessId proc)))
      (RawScheduler.spawn task)
    )



{-| Create a task kills a process.
-}
kill : ProcessId msg -> Platform.Task never ()
kill proc =
  Platform.Task
    (RawScheduler.andThen
      (\() -> RawScheduler.Value (Ok ()))
      (RawScheduler.kill proc)
    )

