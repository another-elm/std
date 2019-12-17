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
  = ProcessState
    { root : ProcessRoot state
    , mailbox : List msg
    , receiver : Maybe (msg -> state -> Task state)
    }


type ProcessId msg
  = ProcessId
    { id : UniqueId
    }


type UniqueId = UniqueId Never


async : (DoneCallback val -> TryAbortAction) -> Task val
async =
  AsyncAction


sync : (() -> Task val) -> Task val
sync =
  SyncAction


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

{-| NON PURE!

Will create, **enqueue** and return a new process.

-}
rawSpawn : Task a -> ProcessId never
rawSpawn task =
  enqueue
    (registerNewProcess
      (ProcessId
        { id = Elm.Kernel.Scheduler.getGuid()
        }
      )
      (ProcessState
        { root = Ready task
        , mailbox = []
        , receiver = Nothing
        }
      )
    )


{-| NON PURE!

Will modify an existing process, **enqueue** and return it.

-}
rawSetReceiver : ProcessId msg -> (msg -> a -> Task a) -> ProcessId msg
rawSetReceiver processId receiver =
  let
    _ =
      updateProcessState
        (\(ProcessState state) ->
          ProcessState
            { state | receiver = Just receiver }
        )
        processId
  in
    enqueue processId


{-| NON PURE!

Send a message to a process and **enqueue** that process so that it
can perform actions based on the message.

-}
rawSend : ProcessId msg -> msg-> ProcessId msg
rawSend processId msg =
  let
    _ =
      updateProcessState
        (\(ProcessState procState) ->
          ProcessState
          { procState | mailbox = procState.mailbox ++ [msg]}
        )
        processId
  in
    enqueue processId



{-| Create a task, if run, will make the process deal with a message.
-}
send : ProcessId msg -> msg -> Task ()
send processId msg =
  async
    (\doneCallback ->
      let
        _ =
          rawSend processId msg
      in
        let
          _ =
            doneCallback (Value ())
        in
      (\() -> ())
    )


{-| Create a task that spawns a processes.
-}
spawn : Task a -> Task (ProcessId never)
spawn task =
  let
    thunk : DoneCallback (ProcessId never) -> TryAbortAction
    thunk doneCallback =
      let
        _ =
          doneCallback (Value (rawSpawn task))
      in
      (\() -> ())
  in
  async
    thunk

{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Task ()
sleep time =
  async (delay time (Value ()))


{-| Create a task kills a process.
-}
kill : ProcessId msg -> Task ()
kill processId =
  let
      (ProcessState { root }) =
        getProcessState processId
  in
  async
    (\doneCallback ->
      let
        _ = case root of
          Running killer ->
              killer ()

          Ready _ ->
            ()
      in
        let
          _ =
            doneCallback (Value ())
        in
        identity
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
        _ =
          updateProcessState (stepper procId) procId
      in
        ()

    )
    id

-- Helper types --




-- Helper functions --

{-| NON PURE! (calls enqueue)

This function **must** return a process with the **same ID** as
the process it is passed as  an argument

-}
stepper : ProcessId msg -> ProcessState msg state -> ProcessState msg state
stepper processId (ProcessState process) =
  let
      _ = Debug.log "id" processId
  in

  case Debug.log "process" process.root of
    Running _ ->
      (ProcessState process)

    Ready (Value val) ->
      case Debug.log "receive" (process.mailbox, process.receiver) of
        (first :: rest, Just receiver) ->
          stepper
            processId
            (ProcessState
              { process
                | root = {- Debug.log "receiverRoot" -} Ready (receiver first val)
                , mailbox = rest
              }
            )

        ([], _) ->
          ProcessState process

        (_, Nothing) ->
          ProcessState process

    Ready (AsyncAction doEffect) ->
      let
        newProcess =
          { process
          | root = {- Debug.log "killableRoot" -} killableRoot
          }

        killableRoot =
          Running
            (doEffect (\newRoot ->
              let
                _ =
                    (updateProcessState
                      (\(ProcessState p) ->
                        ProcessState
                          { p | root = {- Debug.log "newRoot" -} Ready newRoot }
                      )
                      processId
                    )
              in
              let
                -- todo: avoid enqueue here
                  _ =
                    enqueue processId
              in
              ()
            ))
      in
      ProcessState newProcess

    Ready (SyncAction doEffect) ->
      let
        newProcess =
          { process
          | root = {- Debug.log "syncRoot" -} Ready (doEffect ())
          }
      in
      stepper
        processId
        (ProcessState newProcess)


-- Kernel function redefinitons --


updateProcessState : (ProcessState msg state -> ProcessState msg state) -> ProcessId msg -> ProcessState msg state
updateProcessState =
  Elm.Kernel.Scheduler.updateProcessState


getProcessState : ProcessId msg -> ProcessState msg state
getProcessState =
  Elm.Kernel.Scheduler.getProcess


registerNewProcess : ProcessId msg -> ProcessState msg state -> ProcessId msg
registerNewProcess =
  Elm.Kernel.Scheduler.registerNewProcess


enqueueWithStepper : (ProcessId msg -> ()) -> ProcessId msg -> ProcessId msg
enqueueWithStepper =
  Elm.Kernel.Scheduler.enqueueWithStepper


delay : Float -> Task val -> DoneCallback val -> TryAbortAction
delay =
  Elm.Kernel.Scheduler.delay

cannotBeStepped : ProcessId msg -> DoneCallback state -> TryAbortAction
cannotBeStepped =
  Elm.Kernel.Scheduler.cannotBeStepped
