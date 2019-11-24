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

import Basics exposing (Never, Int, identity, (++), Bool(..))
import Maybe exposing (Maybe(..))
import Elm.Kernel.Basics
import Debug
import Platform.Bag exposing (Bag)
import List exposing ((::))

type Task val
  = Value val
  | AndThen (HiddenValA -> Task val) (Task val)
  | AsyncAction (DoneCallback val -> TryAbortAction) TryAbortAction


type alias DoneCallback val =
  Task val -> ()


type alias TryAbortAction =
  () -> ()

type ProcessState msg
  = ProcessState
    { root : Task HiddenValA
    , stack : List (HiddenValB -> Task HiddenValC)
    , mailbox : List msg
    }


type ProcessId msg
  = ProcessId
    { id : UniqueId
    , receiver : Maybe (msg -> Task HiddenValA)
    }


type HiddenValA
  = HiddenValA Never


type HiddenValB
  = HiddenValB Never


type HiddenValC
  = HiddenValC Never


type UniqueId = UniqueId Never


binding : (DoneCallback val -> TryAbortAction) -> Task val
binding callback =
  AsyncAction
    callback
    identity


andThen : (a -> Task b) -> Task a -> Task b
andThen func task =
  AndThen
    (Elm.Kernel.Basics.fudgeType func)
    (Elm.Kernel.Basics.fudgeType task)

{-| NON PURE!

Will create, **enqueue** and return a new process.

-}
rawSpawn : Task a -> ProcessId never
rawSpawn task =
  enqueue
    (registerNewProcess
      (ProcessId
        { id = Elm.Kernel.Sceduler.getGuid()
        , receiver = Nothing
        }
      )
      (ProcessState
        { root = (Elm.Kernel.Basics.fudgeType task)
        , mailbox = []
        , stack = []
        }
      )
    )


{-| NON PURE!

Send a message to a process and **enqueue** that process so that it
can perform actions based on the message.

-}
rawSend : ProcessId msg -> msg-> ProcessId msg
rawSend processId msg =
  enqueue
    (updateProcessState
      (\(ProcessState procState) -> ProcessState { procState | mailbox = procState.mailbox ++ [msg]})
      processId
    )


{-| Create a task, if run, will make the process deal with a message.
-}
send : ProcessId msg -> msg -> Task ()
send processId msg =
  binding
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
  binding
    (\doneCallback ->
      let
        _ =
          doneCallback (Value (rawSpawn task))
      in
      (\() -> ())
    )


{-| Create a task kills a process.
-}
kill : ProcessId msg -> Task ()
kill processId =
  let
      (ProcessState { root }) =
        getProcessState processId
  in
  binding
    (\doneCallback ->
      let
        _ = case root of
          AsyncAction _ killer ->
              killer ()

          _ ->
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


-- {-| NON PURE!
-- -}
-- rawStepper : Process -> Process
-- rawStepper (Process process) =
--   let
--     (doEnqueue, newProcess) =
--       stepper process

--     _ =
--       if doEnqueue then
--         enqueue newProcess
--       else
--         newProcess
--   in
--     newProcess



{-| NON PURE!

This function **must** return a process with the **same ID** as
the process it is passed as  an argument

-}
stepper : ProcessId msg -> ProcessState msg -> ProcessState msg
stepper (ProcessId processId) (ProcessState process) =
  let
      (ProcessState steppedProcess) =
        case process.root of
          Value val ->
            let
              moveStackFowards stack =
                case stack of
                  callback :: rest ->
                    stepper
                      (ProcessId processId)
                      (ProcessState
                        { process
                          | root = (Elm.Kernel.Basics.fudgeType (callback (Elm.Kernel.Basics.fudgeType val)))
                          , stack = rest
                        }
                      )

                  _ ->
                    (ProcessState process)

            in
              moveStackFowards process.stack
          AsyncAction doEffect killer ->
            let
              newProcess =
                { process
                | root = killableRoot
                }

              killableRoot =
                AsyncAction
                  (Debug.todo "put an assert(false) function here?")
                  (doEffect (\newRoot ->
                    let
                      -- todo: avoid enqueue here
                      _ =
                        enqueue
                          (Elm.Kernel.Scheduler.register
                            (ProcessState { process | root = newRoot })
                          )
                    in
                    ()
                  ))
            in
            ProcessState newProcess
          AndThen callback task ->
            stepper
              (ProcessId processId)
              (ProcessState
                { process
                  | root = task
                  , stack = (Elm.Kernel.Basics.fudgeType callback) :: process.stack
                }
              )
  in
    case (steppedProcess.mailbox, processId.receiver) of
      (first :: rest, Just receiver) ->
        stepper
          (ProcessId processId)
          (ProcessState
            { process
              | root = receiver first
              , mailbox = rest
            }
          )

      ([], _) ->
        ProcessState process

      (_, Nothing) ->
        ProcessState process


-- Kernel function redefinitons --


updateProcessState : (ProcessState msg -> ProcessState msg) -> ProcessId msg -> ProcessId msg
updateProcessState =
  Elm.Kernel.Scheduler.updateProcessState


getProcessState : ProcessId msg -> ProcessState msg
getProcessState =
  Elm.Kernel.Scheduler.getProcess


registerNewProcess : ProcessId msg -> ProcessState msg -> ProcessId msg
registerNewProcess =
  Elm.Kernel.Scheduler.registerNewProcess


enqueueWithStepper : (ProcessId msg -> ()) -> ProcessId msg -> ProcessId msg
enqueueWithStepper =
  Elm.Kernel.Scheduler.enqueue
