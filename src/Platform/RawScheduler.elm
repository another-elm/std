module Platform.RawScheduler exposing (DoneCallback, ProcessId(..), Task(..), TryAbortAction, andThen, delay, execImpure, kill, map, newProcessId, rawSend, rawSpawn, send, sleep, spawn)

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
import Elm.Kernel.Scheduler
import Maybe exposing (Maybe(..))


type Task val receive
    = Value val
    | AsyncAction (DoneCallback val receive -> TryAbortAction)
    | SyncAction (() -> Task val receive)
    | Receive (receive -> Task val receive)
    | TryReceive (Maybe receive -> Task val receive)


type alias DoneCallback val receive =
    Task val receive -> ()


type alias TryAbortAction =
    () -> ()


type ProcessState receive state
    = Ready (Task state receive)
    | Running TryAbortAction


type ProcessId msg recv
    = ProcessId { id : UniqueId }


type Channel receive
    = Channel


type UniqueId
    = UniqueId UniqueId


andThen : (a -> Task b receive) -> Task a receive -> Task b receive
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

        Receive receiver ->
            Receive
                (\message ->
                    andThen func (receiver message)
                )

        TryReceive receiver ->
            TryReceive
                (\message ->
                    andThen func (receiver message)
                )


channel : () -> Task (Channel receive) receive
channel () =
    Value Channel


recv : (receive -> a) -> Channel receive -> Task a receive
recv fn chl =
    Receive (\r -> Value (fn r))


tryRecv : (Maybe receive -> a) -> Channel receive -> Task a receive
tryRecv fn chl =
    TryReceive (\r -> Value (fn r))


{-| Create a task that executes a non pure function
-}
execImpure : (() -> a) -> Task a receive
execImpure func =
    SyncAction
        (\() -> Value (func ()))


map : (a -> b) -> Task a receive -> Task b receive
map func =
    andThen (\x -> Value (func x))


{-| Create a new, unique, process id.

Will not register the new process id, just create it. To run any tasks using
this process it needs to be registered, for that use `rawSpawn`.

**WARNING**: trying to enqueue (for example by calling `rawSend` or `send`)
this process before it has been registered will give a **runtime** error. (It
may even fail silently in optimized compiles.)

-}
newProcessId : () -> ProcessId msg recv
newProcessId () =
    ProcessId { id = getGuid () }


{-| NON PURE!

Will create, register and **enqueue** a new process.

-}
rawSpawn : (msg -> a -> Task a Never) -> Task a Never -> ProcessId msg Never -> ProcessId msg Never
rawSpawn receiver initTask processId =
    enqueue
        (registerNewProcess
            processId
            receiver
            (Ready initTask)
        )


{-| NON PURE!

Send a message to a process (adds the message to the processes mailbox) and
**enqueue** that process.

If the process is "ready" it will then act upon the next message in its
mailbox.

-}
rawSend : ProcessId msg Never -> msg -> ProcessId msg Never
rawSend processId msg =
    let
        _ =
            mailboxAdd msg processId
    in
    enqueue processId


{-| Create a task, if run, will make the process deal with a message.
-}
send : ProcessId msg Never -> msg -> Task () receive
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
spawn : (msg -> a -> Task a Never) -> Task a Never -> Task (ProcessId msg Never) Never
spawn receiver task =
    SyncAction
        (\() -> Value (rawSpawn receiver task (newProcessId ())))


{-| Create a task that sleeps for `time` milliseconds
-}
sleep : Float -> Task () receive
sleep time =
    AsyncAction (delay time (Value ()))


{-| Create a task kills a process.

To kill a process we should try to abort any ongoing async action.
We only allow processes that cannot receive messages to be killed, we will
allow the offical core library to lead the way regarding processes that can
receive values.

-}
kill : ProcessId Never Never -> Task () receive
kill processId =
    SyncAction
        (\() ->
            let
                () =
                    case getProcessState processId of
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
enqueue : ProcessId msg recv -> ProcessId msg recv
enqueue id =
    enqueueWithStepper
        (\procId ->
            let
                onAsyncActionDone =
                    runOnNextTick
                        (\newRoot ->
                            let
                                _ =
                                    updateProcessState
                                        (\_ -> Ready newRoot)
                                        procId
                            in
                            let
                                (ProcessId _) =
                                    enqueue procId
                            in
                            ()
                        )

                _ =
                    updateProcessState (stepper procId onAsyncActionDone) procId
            in
            ()
        )
        id



-- Helper functions --


{-| NON PURE! (calls enqueue)

This function **must** return a process with the **same ID** as
the process it is passed as an argument

-}
stepper : ProcessId msg receive -> (Task state receive -> ()) -> ProcessState receive state -> ProcessState receive state
stepper processId onAsyncActionDone process =
    case process of
        Running _ ->
            process

        Ready (Value val) ->
            case mailboxReceive processId val of
                Just newRoot ->
                    stepper
                        processId
                        onAsyncActionDone
                        (Ready newRoot)

                Nothing ->
                    process

        Ready (AsyncAction doEffect) ->
            Running (doEffect onAsyncActionDone)

        Ready (SyncAction doEffect) ->
            stepper
                processId
                onAsyncActionDone
                (Ready (doEffect ()))

        Ready (Receive receiver) ->
            case rawTryRecv processId of
                Just received ->
                    stepper
                        processId
                        onAsyncActionDone
                        (Ready (receiver received))

                Nothing ->
                    process

        Ready (TryReceive receiver) ->
            stepper
                processId
                onAsyncActionDone
                (Ready (receiver (rawTryRecv processId)))



-- Kernel function redefinitons --


getGuid : () -> UniqueId
getGuid =
    Elm.Kernel.Scheduler.getGuid


updateProcessState : (ProcessState recv state -> ProcessState recv state) -> ProcessId msg recv -> ProcessState recv state
updateProcessState =
    Elm.Kernel.Scheduler.updateProcessState


mailboxAdd : msg -> ProcessId msg Never -> msg
mailboxAdd =
    Elm.Kernel.Scheduler.mailboxAdd


mailboxReceive : ProcessId msg recv -> state -> Maybe (Task state recv)
mailboxReceive =
    Elm.Kernel.Scheduler.mailboxReceive


rawTryRecv : ProcessId msg receive -> Maybe receive
rawTryRecv =
    Elm.Kernel.Scheduler.rawTryRecv


getProcessState : ProcessId msg recv -> ProcessState recv state
getProcessState =
    Elm.Kernel.Scheduler.getProcessState


registerNewProcess : ProcessId msg recv -> (msg -> state -> Task state recv) -> ProcessState receive state -> ProcessId msg recv
registerNewProcess =
    Elm.Kernel.Scheduler.registerNewProcess


enqueueWithStepper : (ProcessId msg recv -> ()) -> ProcessId msg recv -> ProcessId msg recv
enqueueWithStepper =
    Elm.Kernel.Scheduler.enqueueWithStepper


delay : Float -> Task val receive -> DoneCallback val receive -> TryAbortAction
delay =
    Elm.Kernel.Scheduler.delay


runOnNextTick : (a -> ()) -> a -> ()
runOnNextTick =
    Elm.Kernel.Scheduler.runOnNextTick
