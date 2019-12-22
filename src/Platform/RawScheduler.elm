module Platform.RawScheduler exposing (..)

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

import Basics exposing (..)
import Maybe exposing (Maybe(..))
import Elm.Kernel.Basics
import Elm.Kernel.Scheduler
import List exposing ((::))
import Debug

type Task val
  = Value val
  | AsyncAction (DoneCallback val -> TryAbortAction)
  | SyncAction (() -> Task val)

type alias DoneCallback val =
  Task val -> ()


type alias TryAbortAction =
  () -> ()


type ProcessRoot state
  = Ready (Task state)
  | Running TryAbortAction


type ProcessState msg state
  = ProcessState (ProcessRoot state)


type ProcessId msg
  = ProcessId UniqueId


type UniqueId = UniqueId UniqueId


andThen : (a -> Task b) -> Task a -> Task b
andThen func task =
  case task of
    Value val ->
      func val

    SyncAction thunk ->
      SyncAction (\() -> andThen func (thunk ()))

    AsyncAction doEffect ->
      AsyncAction
        (\doneCallback ->
          doEffect
            (\newTask -> doneCallback (andThen func newTask))
        )


{-| Create a new, unique, process id.

Will not register the new process id, just create it. To run any tasks using
this process it needs to be registered, for that use `rawSpawn`.

**WARNING**: trying to enqueue (for example by calling `rawSend` or `send`)
this process before it has been registered will give a **runtime** error. (It
may even fail silently in optimized compiles.)

-}
newProcessId : () -> ProcessId msg
newProcessId () =
  ProcessId (Elm.Kernel.Scheduler.getGuid())


{-| NON PURE!

Will create, register and  **enqueue** a new process.

-}
rawSpawn : (msg -> a -> Task a) -> Task a -> ProcessId msg -> ProcessId msg
rawSpawn receiver initTask processId =
  enqueue
    (registerNewProcess
      processId
      receiver
      (ProcessState (Ready initTask))
    )


{-| NON PURE!

Send a message to a process (adds the message to the processes mailbox) and
**enqueue** that process.

If the process is "ready" it will then act upon the next message in its
mailbox.

-}
rawSend : ProcessId msg -> msg -> ProcessId msg
rawSend processId msg =
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


{-| Create a task that spawns a processes.
-}
spawn : (msg -> a -> Task a) -> Task a -> Task (ProcessId msg)
spawn receiver task =
  SyncAction
    (\() -> Value (rawSpawn receiver task (newProcessId ())))


{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Task ()
sleep time =
  AsyncAction (delay time (Value ()))


{-| Create a task kills a process.

  To kill a process we should try to abort any ongoing async action.
  We only allow processes that cannot receive messages to be killed, we will
  on the offical core library to lead the way regarding processes that can
  receive values.
-}
kill : ProcessId Never -> Task ()
kill processId =
  SyncAction
    (\() ->
      let
        (ProcessState root) =
          getProcessState processId

        () =
          case root of
            Running killer ->
                killer ()

            Ready _ ->
              ()
      in
        Value ()
    )


{-| NON PURE!

Add a `Process` to the run queue and, unless this is a reenterant
call, drain the run queue but stepping all processes.
Returns the enqueued `Process`.

-}
enqueue : ProcessId msg -> ProcessId msg
enqueue id =
  enqueueWithStepper
    (\procId ->
      let
        onAsyncActionDone =
          runOnNextTick
            (\newRoot ->
              let
                (ProcessState (_)) =
                  (updateProcessState
                    (\(ProcessState p) ->
                      ProcessState (Ready newRoot)
                    )
                    procId
                  )
              in
              let
                (ProcessId _) =
                  enqueue procId
              in
              ()
            )

        (ProcessState _) =
          updateProcessState (stepper procId onAsyncActionDone) procId
      in
        ()
    )
    id


-- Helper functions --

{-| NON PURE! (calls enqueue)

This function **must** return a process with the **same ID** as
the process it is passed as  an argument

-}
stepper : ProcessId msg -> (Task state -> ()) -> ProcessState msg state -> ProcessState msg state
stepper processId onAsyncActionDone (ProcessState process) =
  case process of
    Running _ ->
      (ProcessState process)

    Ready (Value val) ->
      case mailboxReceive processId val of
        Just newRoot ->
          stepper
            processId
            onAsyncActionDone
            (ProcessState (Ready newRoot))

        Nothing ->
          ProcessState process

    Ready (AsyncAction doEffect) ->
      ProcessState (Running (doEffect onAsyncActionDone))

    Ready (SyncAction doEffect) ->
      stepper
        processId
        onAsyncActionDone
        (ProcessState (Ready (doEffect ())))


-- Kernel function redefinitons --


updateProcessState : (ProcessState msg state -> ProcessState msg state) -> ProcessId msg -> ProcessState msg state
updateProcessState =
  Elm.Kernel.Scheduler.updateProcessState


mailboxAdd : msg -> ProcessId msg -> msg
mailboxAdd =
  Elm.Kernel.Scheduler.mailboxAdd


mailboxReceive : ProcessId msg -> state -> Maybe (Task state)
mailboxReceive =
  Elm.Kernel.Scheduler.mailboxReceive


getProcessState : ProcessId msg -> ProcessState msg state
getProcessState =
  Elm.Kernel.Scheduler.getProcessState


registerNewProcess : ProcessId msg -> (msg -> state -> Task state) -> ProcessState msg state -> ProcessId msg
registerNewProcess =
  Elm.Kernel.Scheduler.registerNewProcess


enqueueWithStepper : (ProcessId msg -> ()) -> ProcessId msg -> ProcessId msg
enqueueWithStepper =
  Elm.Kernel.Scheduler.enqueueWithStepper


delay : Float -> Task val -> DoneCallback val -> TryAbortAction
delay =
  Elm.Kernel.Scheduler.delay


runOnNextTick : (a -> ()) -> a -> ()
runOnNextTick =
  Elm.Kernel.Scheduler.runOnNextTick
