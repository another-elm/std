module Platform.Scheduler exposing (unwrapProcessId, unwrapTask, wrapProcessId, wrapTask)

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

import Elm.Kernel.Basics
import Elm.Kernel.Platform
import Platform
import Platform.Unstable.Scheduler as RawScheduler
import Platform.Unstable.Task as RawTask


wrapTask : RawTask.Task e o -> Platform.Task e o
wrapTask =
    Elm.Kernel.Basics.fudgeType


unwrapTask : Platform.Task e o -> RawTask.Task e o
unwrapTask =
    Elm.Kernel.Basics.fudgeType


wrapProcessId : RawScheduler.ProcessId -> Platform.ProcessId
wrapProcessId =
    Elm.Kernel.Basics.fudgeType


unwrapProcessId : Platform.ProcessId -> RawScheduler.ProcessId
unwrapProcessId =
    Elm.Kernel.Basics.fudgeType
