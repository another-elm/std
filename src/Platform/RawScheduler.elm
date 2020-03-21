module Platform.RawScheduler exposing (DoneCallback, ProcessId(..), Task(..), TryAbortAction, UniqueId, andThen, execImpure, getGuid, kill, map, rawSpawn, sleep, spawn)

{-| This module contains the low level logic for running tasks and processes. A
`Task` is a sequence of actions (either syncronous or asyncronous) that will be
run in order by the runtime. A process (outside this module a process is
accessed and manipulated using its unique id) is a task paired with a
"receiver". If a process is sent a message (using the `send` function) it is
added to the processes mailbox. When the process completes execution of its
current `Task` (or immediately if it has already finished execution of its
`Task`) it will envoke its receiver function with the oldest message in the
mailbox and the final state of its `Task`. The receiver function should produce
a new `Task` for the process to execute.

Processes spawned by user elm code (using `Process.spawn`) cannot receive
messages so will execute their initial `Task` and then die.

Only two modules should import this module directly `Platform.Scheduler` and
`Platform`. All other modules should import `Platform.Scheduler` which has a
nicer API. `Platform` cannot import `Platform.Scheduler` as
`Platfrom.Scheduler` imports `Platform` and elm does not allow import cycles.

-}

import Basics exposing (..)
import Debug
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))


type Task val
    = Value val
    | AsyncAction (DoneCallback val -> TryAbortAction)


type alias DoneCallback val =
    Task val -> ()


type alias TryAbortAction =
    () -> ()


type ProcessState msg state
    = Ready (Task state)
    | Running TryAbortAction


type ProcessId msg
    = ProcessId { id : UniqueId }


type UniqueId
    = UniqueId UniqueId


andThen : (a -> Task b) -> Task a -> Task b
andThen func task =
    case task of
        Value val ->
            func val

        AsyncAction doEffect ->
            AsyncAction
                (\doneCallback ->
                    doEffect
                        (\newTask -> doneCallback (andThen func newTask))
                )


{-| Create a task that executes a non pure function
-}
execImpure : (() -> a) -> Task a
execImpure func =
    AsyncAction
        (\doneCallback ->
            let
                () =
                    doneCallback (Value (func ()))
            in
            \() -> ()
        )


map : (a -> b) -> Task a -> Task b
map func =
    andThen (\x -> Value (func x))


{-| NON PURE!

Will create, register and **enqueue** a new process.

-}
rawSpawn : Task a -> ProcessId msg
rawSpawn initTask =
    enqueue
        (registerNewProcess
            (ProcessId { id = getGuid () })
            (Ready initTask)
        )


{-| Create a task that spawns a processes.
-}
spawn : Task a -> Task (ProcessId msg)
spawn task =
    execImpure (\() -> rawSpawn task)


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
    execImpure
        (\() ->
            case getProcessState processId of
                Running killer ->
                    killer ()

                Ready _ ->
                    ()
        )


{-| NON PURE!

Add a `Process` to the run queue and, unless this is a reenterant
call, drain the run queue but stepping all processes.
Returns the enqueued `Process`.

-}
enqueue : ProcessId msg -> ProcessId msg
enqueue =
    enqueueWithStepper stepper



-- Helper functions --


{-| NON PURE! (calls enqueue)

This function **must** return a process with the **same ID** as
the process it is passed as an argument

-}
stepper : ProcessId msg -> ProcessState msg state -> ProcessState msg state
stepper processId process =
    case process of
        Running _ ->
            case getWokenValue processId of
                Just root ->
                    createStateWithRoot processId root

                Nothing ->
                    process

        Ready root ->
            createStateWithRoot processId root


createStateWithRoot : ProcessId msg -> Task state -> ProcessState msg state
createStateWithRoot processId root =
    case root of
        Value val ->
            Ready (Value val)

        AsyncAction doEffect ->
            Running
                (doEffect
                    (\newRoot ->
                        let
                            () =
                                setWakeTask processId newRoot
                        in
                        let
                            (ProcessId _) =
                                enqueue processId
                        in
                        ()
                    )
                )



-- Kernel function redefinitons --


getGuid : () -> UniqueId
getGuid =
    Elm.Kernel.Scheduler.getGuid


getProcessState : ProcessId msg -> ProcessState msg state
getProcessState =
    Elm.Kernel.Scheduler.getProcessState


registerNewProcess : ProcessId msg -> ProcessState msg state -> ProcessId msg
registerNewProcess =
    Elm.Kernel.Scheduler.registerNewProcess


enqueueWithStepper : (ProcessId msg -> ProcessState msg state -> ProcessState msg state) -> ProcessId msg -> ProcessId msg
enqueueWithStepper =
    Elm.Kernel.Scheduler.enqueueWithStepper


delay : Float -> Task val -> DoneCallback val -> TryAbortAction
delay =
    Elm.Kernel.Scheduler.delay


getWokenValue : ProcessId msg -> Maybe (Task state)
getWokenValue =
    Elm.Kernel.Scheduler.getWokenValue


setWakeTask : ProcessId msg -> Task state -> ()
setWakeTask =
    Elm.Kernel.Scheduler.setWakeTask
