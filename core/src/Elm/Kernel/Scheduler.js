/*

import Platform.Scheduler as NiceScheduler exposing (succeed, binding, rawSpawn)
import Maybe exposing (Just, Nothing)
import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Basics exposing (isDebug)
*/

// COMPATIBILITY

/*
 * We include these to avoid having to change code in other `elm/*` packages.
 *
 * We have to define these as functions rather than variables as the
 * implementations of elm/core:Platform.Scheduler.* functions may come later in
 * the generated javascript file.
 *
 * **IMPORTANT**: these functions return `Process.Task`s and
 * `Process.ProcessId`s rather than `RawScheduler.Task`s and
 * `RawScheduler.ProcessId`s for compatability with `elm/*` package code.
 */

function _Scheduler_succeed(value) {
  return __NiceScheduler_succeed(value);
}

function _Scheduler_binding(future) {
  return __NiceScheduler_binding(future);
}

function _Scheduler_rawSpawn(task) {
  return __NiceScheduler_rawSpawn(task);
}

// SCHEDULER

var _Scheduler_guid = 0;
var _Scheduler_processes = new WeakMap();

function _Scheduler_getGuid() {
  return _Scheduler_guid++;
}

function _Scheduler_getProcessState(id) {
  const procState = _Scheduler_processes.get(id);
  if (procState === undefined) {
    return __Maybe_Nothing;
  }
  return __Maybe_Just(procState);
}

var _Scheduler_registerNewProcess = F2((procId, procState) => {
  if (__Basics_isDebug && _Scheduler_processes.has(procId)) {
    __Debug_crash(
      12,
      __Debug_runtimeCrashReason("procIdAlreadyRegistered"),
      procId && procId.a && procId.a.__$id
    );
  }
  _Scheduler_processes.set(procId, procState);
  return procId;
});

const _Scheduler_enqueueWithStepper = (stepper) => {
  let working = false;
  const queue = [];

  return (procId) => (rootTask) => {
    if (__Basics_isDebug && queue.some((p) => p[0].a.__$id === procId.a.__$id)) {
      __Debug_crash(
        12,
        __Debug_runtimeCrashReason("procIdAlreadyInQueue"),
        procId && procId.a && procId.a.__$id
      );
    }
    queue.push([procId, rootTask]);
    if (working) {
      return procId;
    }
    working = true;
    while (true) {
      const next = queue.shift();
      if (next === undefined) {
        working = false;
        return procId;
      }
      const [newProcId, newRootTask] = next;
      _Scheduler_processes.set(newProcId, A2(stepper, newProcId, newRootTask));
    }
  };
};

const _Scheduler_delay = F2((time, value) => ({
  __$then_: (callback) => () => {
    let id = setTimeout(() => {
      callback(value)();
    }, time);
    return (x) => {
      if (id !== null) {
        clearTimeout(id);
        id = null;
      }
      return x;
    };
  },
}));
