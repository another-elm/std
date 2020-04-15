module Platform.Raw.Scheduler exposing (ProcessId, UniqueId, batch, getGuid, kill, rawSpawn, spawn)

{-| This module contains the low level logic for processes. A process is a
unique id used to execute tasks.
-}

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import List
import Maybe exposing (Maybe(..))
import Platform.Raw.Task as RawTask


type ProcessState state
    = Ready (RawTask.Task state)
    | Running RawTask.TryAbortAction


type ProcessId
    = ProcessId { id : UniqueId }


type UniqueId
    = UniqueId UniqueId


{-| NON PURE!

Will create, register and **enqueue** a new process.

-}
rawSpawn : RawTask.Task a -> ProcessId
rawSpawn initTask =
    enqueue
        (ProcessId { id = getGuid () })
        initTask


{-| Create a task that spawns a processes.
-}
spawn : RawTask.Task a -> RawTask.Task ProcessId
spawn task =
    RawTask.execImpure (\() -> rawSpawn task)


{-| Create a task kills a process.

To kill a process we should try to abort any ongoing async action.
We only allow processes that cannot receive messages to be killed, we will
on the offical core library to lead the way regarding processes that can
receive values.

-}
kill : ProcessId -> RawTask.Task ()
kill processId =
    RawTask.execImpure (\() -> rawKill processId)


batch : List ProcessId -> RawTask.Task ProcessId
batch ids =
    spawn
        (RawTask.AsyncAction
            (\doneCallback ->
                let
                    () =
                        doneCallback (spawn (RawTask.Value ()))
                in
                \() ->
                    List.foldr
                        (\id () -> rawKill id)
                        ()
                        ids
            )
        )


{-| NON PURE!

Add a `Process` to the run queue and, unless this is a reenterant
call, drain the run queue but stepping all processes.
Returns the enqueued `Process`.

-}
enqueue : ProcessId -> RawTask.Task state -> ProcessId
enqueue =
    enqueueWithStepper stepper



-- Helper functions --


{-| NON PURE! (calls enqueue)

This function **must** return a process with the **same ID** as
the process it is passed as an argument

-}
stepper : ProcessId -> RawTask.Task state -> ProcessState state
stepper processId root =
    case root of
        RawTask.Value val ->
            Ready (RawTask.Value val)

        RawTask.AsyncAction doEffect ->
            Running
                (doEffect
                    (\newRoot ->
                        let
                            (ProcessId _) =
                                enqueue processId newRoot
                        in
                        ()
                    )
                )


{-| NON PURE!
-}
rawKill : ProcessId -> ()
rawKill id =
    case getProcessState id of
        Just (Running killer) ->
            killer ()

        Just (Ready _) ->
            ()

        Nothing ->
            ()



-- Kernel function redefinitons --


getGuid : () -> UniqueId
getGuid =
    Elm.Kernel.Scheduler.getGuid


getProcessState : ProcessId -> Maybe (ProcessState state)
getProcessState =
    Elm.Kernel.Scheduler.getProcessState


enqueueWithStepper : (ProcessId -> RawTask.Task state -> ProcessState state) -> ProcessId -> RawTask.Task state -> ProcessId
enqueueWithStepper =
    Elm.Kernel.Scheduler.enqueueWithStepper
