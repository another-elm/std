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

import Basics exposing (Never, Int, (++), Bool(..))
import Maybe exposing (Maybe(..))
import Elm.Kernel.Basics
import Debug
import List exposing ((::))

type Task err ok
  = Succeed ok
  | Fail err
  | Binding (BindingCallbackAlias err ok) (Maybe KillThunk)
    -- todo binding callback type args
  | AndThen (HiddenOk -> Task err ok) (Task err HiddenOk)
  | OnError (HiddenErr -> Task err ok) (Task HiddenErr ok)
  | Receive (HiddenMsg -> Task err ok)


type Process msg
  = Process
    { id : Id msg
    , root : Task HiddenErr HiddenOk
    , stack : List (StackItem HiddenErr HiddenOk)
    , mailbox : List msg
    }


binding : BindingCallbackAlias err ok -> Task err ok
binding callback =
  Binding
    callback
    Nothing

{-| NON PURE!

Will create, **enqueue** and return a new process.

-}
rawSpawn : Task err ok -> Process msg
rawSpawn task =
  enqueue (Elm.Kernel.Scheduler.register
      (Process
        { id = Elm.Kernel.Sceduler.getGuid()
        , root = Elm.Kernel.Basics.fudgeType task
        , stack = []
        , mailbox = []
        }
      )
  )


{-| NON PURE!

Send a message to a process and **enqueue** that process so that it
can perform actions based on the message.

-}
rawSend : Process msg -> msg -> Process msg
rawSend (Process proc) msg =
  enqueue (Elm.Kernel.Scheduler.register
    (Process { proc | mailbox = proc.mailbox ++ [msg]})
  )


{-| Create a task for that has a process deal with a message.
-}
send : Id msg -> msg -> Task x ()
send processId msg =
  binding
    (\doneCallback ->
      let
        proc =
          Elm.Kernel.Scheduler.getProcess processId

        _ =
          Succeed (rawSend proc msg)
      in
        let
          _ =
            doneCallback (Succeed ())
        in
        Nothing
    )


{-| Create a task that spawns a processes.
-}
spawn : Task err ok -> Task never (Id msg)
spawn task =
  binding
    (\doneCallback ->
    let
      (Process proc) =
        rawSpawn task

      _ =
        doneCallback (Succeed proc.id)
    in
      Nothing
    )


{-| Create a task kills a process.
-}
kill : Process msg -> Task x ()
kill (Process { root }) =
  binding
    (\doneCallback ->
      let
        _ = case root of
          Binding _ (Just (killer)) ->
            let
              (KillThunk thunk) = killer
            in
              thunk ()

          _ ->
            ()
      in
        let
          _ =
            doneCallback (Succeed ())
        in
        Nothing
    )


{-| NON PURE!

Add a `Process` to the run queue and, unless this is a reenterant
call, drain the run queue but stepping all processes.
Returns the enqueued `Process`.

-}
enqueue : Process msg -> Process msg
enqueue (Process process) =
  let
    _ = Elm.Kernel.Scheduler.enqueue stepper process.id
  in
    (Process process)

-- Helper types --


type Id msg = Id Never


type HiddenOk = HiddenOk Never


type HiddenErr = HiddenErr Never


type HiddenMsg = HiddenMsg Never


type KillThunk = KillThunk (() -> ())


type alias BindingCallbackAlias err ok =
  ((Task err ok -> ()) -> Maybe KillThunk)


type StackItem err ok
  = StackSucceed (HiddenOk -> Task err ok)
  | StackFail (HiddenErr-> Task err ok)


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
stepper : Process msg -> Process msg
stepper (Process process) =
  case process.root of
    Succeed val ->
      let
        moveStackFowards stack =
          case stack of
            (StackFail _) :: rest ->
              moveStackFowards rest

            (StackSucceed callback) :: rest ->
              stepper (Process
                  { process
                    | root = callback val
                    , stack = rest
                  }
                )

            _ ->
              (Process process)

      in
        moveStackFowards process.stack
    Fail error ->
      let
        moveStackFowards stack =
          case stack of
            (StackSucceed _) :: rest ->
              moveStackFowards rest

            (StackFail callback) :: rest ->
              stepper (Process
                  { process
                    | root = callback error
                    , stack = rest
                  }
                )

            _ ->
              (Process process)

      in
        moveStackFowards process.stack
    Binding doEffect killer ->
      let
        newProcess =
          { process
          | root = killableRoot
          }

        killableRoot =
          Binding
            (Debug.todo "put an assert(false) function here?")
            (doEffect (\newRoot ->
              let
                -- todo: avoid enqueue here
                _ =
                  enqueue
                    (Elm.Kernel.Scheduler.register
                      (Process { process | root = newRoot })
                    )
              in
              ()
            ))
      in
      Process newProcess
    Receive callback ->
      case process.mailbox of
        [] ->
          Process process
        first :: rest ->
          stepper
            (Process
              { process
                | root = callback first
                , mailbox = rest
              }
            )
    AndThen callback task ->
      stepper
        (Process
          { process
            | root = task
            , stack = (StackSucceed callback) :: process.stack
          }
        )
    OnError callback task ->
      stepper
        (Process
          { process
            | root = task
            , stack = (StackFail callback) :: process.stack
          }
        )




