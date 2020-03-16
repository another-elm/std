module Platform.Scheduler exposing (DoneCallback, ProcessId, TryAbortAction, andThen, binding, fail, kill, onError, rawSpawn, send, sleep, spawn, succeed)

{-| The definition of the `Task` and `ProcessId` really belong in the
`Platform.RawScheduler` module for two reasons.

1.  Tasks and processes are created, run and managed by the scheduler. It makes
    semantic sense for the scheduler to also contain the type defintion.
2.  The `Platform.RawScheduler` module is private to `elm/core`, therefore other
    core functions could access the type constructurs if they were contained
    within the module. `Platform` is a public module and therefore we cannot
    expose the type constructures to core functions without also exposing them
    to user functions.

However, for two reasons they must instead be defined in the `Platform` module.

1.  The official elm compiler regards changing a type definition to a type alias
    to be a MAJOR change. Moving the type definition out of `Platform` and
    replacing it with a type alias would count as a MAJOR change. As one of my
    aims for this alternative elm/core library was no MAJOR (or even MINOR
    changes) according to elm diff. Moving `Task` and `ProcessId` out of
    `Platform` would defeat this aim.
2.  More seriously, there are hard coded checks in the elm compiler ensuring
    effect modules are valid. The compiler checks that the module defines the
    needed functions (for example `onEffects`, `onSelfMsg`, etc) but it also
    checks that the type signatures of these functions are correct. If we
    replace the type definitions in `Platform` by type aliases all these checks
    start to fail. For example, the compile checks that `Task.onEffects` returns
    a `Platform.Task` but actually it returns `Platform.RawScheduler.Task` (via
    a type alias in `Platform` but type aliases are transparent to the compiler
    at this point during compiliation).

In an attempt to get the best of both worlds we define `Task` and `ProcessId`
types in `Platform.RawScheduler` and then in `Platform` we define

    type Task error value
        = Task (Platform.RawScheduler.Task (Result error value))

This module provides functions that work with `Platform.Task`s and
`Platform.ProcessId`s. However, as the type constructors are not exposed (if
they were the user code could use the runtime internals), this module resorts
to some kernel code magic to wrap and unwrap `Task`s and `Process`s.

-}

import Basics exposing (..)
import Elm.Kernel.Basics
import Elm.Kernel.Platform
import Platform
import Platform.RawScheduler as RawScheduler
import Result exposing (Result(..))


type alias ProcessId msg =
    RawScheduler.ProcessId msg Never


type alias DoneCallback err ok =
    Platform.Task err ok -> ()


type alias TryAbortAction =
    RawScheduler.TryAbortAction


succeed : ok -> Platform.Task never ok
succeed val =
    wrapTask (RawScheduler.Value (Ok val))


fail : err -> Platform.Task err never
fail e =
    wrapTask (RawScheduler.Value (Err e))


binding : (DoneCallback err ok -> TryAbortAction) -> Platform.Task err ok
binding callback =
    wrapTask
        (RawScheduler.AsyncAction
            (\doneCallback -> callback (taskFn (\task -> doneCallback task)))
        )


andThen : (ok1 -> Platform.Task err ok2) -> Platform.Task err ok1 -> Platform.Task err ok2
andThen func =
    wrapTaskFn
        (\task ->
            RawScheduler.andThen
                (\r ->
                    case r of
                        Ok val ->
                            unwrapTask (func val)

                        Err e ->
                            RawScheduler.Value (Err e)
                )
                task
        )


onError : (err1 -> Platform.Task err2 ok) -> Platform.Task err1 ok -> Platform.Task err2 ok
onError func =
    wrapTaskFn
        (\task ->
            RawScheduler.andThen
                (\r ->
                    case r of
                        Ok val ->
                            RawScheduler.Value (Ok val)

                        Err e ->
                            unwrapTask (func e)
                )
                task
        )


{-| Create a task, if run, will make the process deal with a message.
-}
send : ProcessId msg -> msg -> Platform.Task never ()
send proc msg =
    wrapTask (RawScheduler.map Ok (RawScheduler.send proc msg))


{-| Create a task that, when run, will spawn a process.

There is no way to send messages to a process spawned in this way.

-}
spawn : Platform.Task err ok -> Platform.Task never Platform.ProcessId
spawn =
    wrapTaskFn
        (\task ->
            RawScheduler.map
                (\proc -> Ok (wrapProcessId proc))
                (RawScheduler.spawn (\msg _ -> never msg) task)
        )


{-| This is provided to make `__Scheduler_rawSpawn` work!

TODO(harry) remove once code in other `elm/*` packages has been updated.

-}
rawSpawn : Platform.Task err ok -> Platform.ProcessId
rawSpawn =
    taskFn
        (\task ->
            wrapProcessId
                (RawScheduler.rawSpawn
                    (\msg _ -> never msg)
                    task
                    (RawScheduler.newProcessId ())
                )
        )


{-| Create a task kills a process.
-}
kill : Platform.ProcessId -> Platform.Task never ()
kill processId =
    wrapTask (RawScheduler.map Ok (RawScheduler.kill (unwrapProcessId processId)))


{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Platform.Task x ()
sleep time =
    wrapTask (RawScheduler.map Ok (RawScheduler.sleep time))



-- wrapping helpers --


wrapTaskFn : (RawScheduler.Task (Result e1 o1) Never -> RawScheduler.Task (Result e2 o2) Never) -> Platform.Task e1 o1 -> Platform.Task e2 o2
wrapTaskFn fn task =
    wrapTask (taskFn fn task)


taskFn : (RawScheduler.Task (Result e1 o1) Never -> a) -> Platform.Task e1 o1 -> a
taskFn fn task =
    fn (unwrapTask task)


wrapTask : RawScheduler.Task (Result e o) Never -> Platform.Task e o
wrapTask =
    Elm.Kernel.Platform.wrapTask


unwrapTask : Platform.Task e o -> RawScheduler.Task (Result e o) Never
unwrapTask =
    Elm.Kernel.Basics.unwrapTypeWrapper


wrapProcessId : ProcessId Never -> Platform.ProcessId
wrapProcessId =
    Elm.Kernel.Platform.wrapProcessId


unwrapProcessId : Platform.ProcessId -> ProcessId Never
unwrapProcessId =
    Elm.Kernel.Basics.unwrapTypeWrapper
