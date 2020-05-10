module Platform.Raw.Scheduler exposing (ProcessId, UniqueId, batch, getGuid, kill, rawSpawn, spawn)

{-| This module contains the low level logic for processes. A process is a
unique id used to execute tasks.
-}

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import List
import Maybe exposing (Maybe(..))
import Platform.Raw.Impure as Impure
import Platform.Raw.Task as RawTask


type ProcessState state
    = Ready (RawTask.Task state)
    | Running RawTask.TryAbortAction


type ProcessId
    = ProcessId { id : UniqueId }


type UniqueId
    = UniqueId UniqueId


{-| Will create, register and **enqueue** a new process.
-}
rawSpawn : Impure.Function (RawTask.Task a) ProcessId
rawSpawn =
    Impure.toFunction (enqueue (ProcessId { id = getGuid () }))


{-| Create a task that spawns a processes.
-}
spawn : RawTask.Task a -> RawTask.Task ProcessId
spawn task =
    RawTask.execImpure (Impure.fromFunction rawSpawn task)


{-| Create a task kills a process.

To kill a process we should try to abort any ongoing async action.
We only allow processes that cannot receive messages to be killed, we will
on the offical core library to lead the way regarding processes that can
receive values.

-}
kill : ProcessId -> RawTask.Task ()
kill processId =
    RawTask.execImpure (rawKill processId)


batch : List ProcessId -> RawTask.Task ProcessId
batch ids =
    spawn
        (RawTask.AsyncAction
            { then_ =
                \doneCallback ->
                    let
                        tryAbort =
                            List.foldr
                                (\id impure -> Impure.andThen (\() -> rawKill id) impure)
                                (Impure.fromPure ())
                                ids
                    in
                    RawTask.Value ()
                        |> Impure.fromPure
                        |> Impure.map spawn
                        |> Impure.andThen doneCallback
                        |> Impure.map (\() -> tryAbort)
            }
        )


{-| Create an Action that adds a `Process` to the run queue and, unless this is a
reenterant call, drain the run queue but stepping all processes. The action
produces the enqueued `ProcessId` when it is run.
-}
enqueue : ProcessId -> RawTask.Task state -> Impure.Action ProcessId
enqueue id =
    let
        stepperFunc id2 =
            Impure.toFunction (stepper id2)
    in
    Impure.fromFunction (enqueueWithStepper stepperFunc id)



-- Helper functions --


{-| Steps a process as far as possible and then enqueues any asyncronous
actions that the process needs to perform.

-}
stepper : ProcessId -> RawTask.Task state -> Impure.Action (ProcessState state)
stepper processId root =
    let
        doneCallback : RawTask.Task state -> Impure.Action ()
        doneCallback newRoot =
            enqueue processId newRoot
                |> Impure.map (\(ProcessId _) -> ())
    in
    case root of
        RawTask.Value val ->
            val
                |> RawTask.Value
                |> Ready
                |> Impure.fromPure

        RawTask.AsyncAction doEffect ->
            doneCallback
                |> doEffect.then_
                |> Impure.map Running


rawKill : ProcessId -> Impure.Action ()
rawKill id =
    case getProcessState id of
        Just (Running killer) ->
            killer

        Just (Ready _) ->
            Impure.fromPure ()

        Nothing ->
            Impure.fromPure ()



-- Kernel function redefinitons --


getGuid : () -> UniqueId
getGuid =
    Elm.Kernel.Scheduler.getGuid


getProcessState : ProcessId -> Maybe (ProcessState state)
getProcessState =
    Elm.Kernel.Scheduler.getProcessState


enqueueWithStepper :
    (ProcessId -> Impure.Function (RawTask.Task state) (ProcessState state))
    -> ProcessId
    -> Impure.Function (RawTask.Task state) ProcessId
enqueueWithStepper =
    Elm.Kernel.Scheduler.enqueueWithStepper
