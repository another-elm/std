/*

import Platform.Scheduler as NiceScheduler exposing (succeed, binding, rawSpawn)
import Platform.Raw.Scheduler as RawScheduler exposing (stepper)
import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Basics exposing (isDebug)
import Elm.Kernel.Utils exposing (Tuple0)
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

let _Scheduler_guid = 0;
const _Scheduler_tryAbortForProcesses = new WeakMap();
const _Scheduler_doNotStep = new WeakSet();
let _Scheduler_working = false;
const _Scheduler_queue = [];

function _Scheduler_getGuid() {
  return _Scheduler_guid++;
}

function _Scheduler_tryAbortProcess(id) {
  _Scheduler_doNotStep.add(id);
  const tryAbortAction = _Scheduler_tryAbortForProcesses.get(id);
  if (tryAbortAction !== undefined) {
    tryAbortAction();
  }
  return __Utils_Tuple0;
}

const _Scheduler_rawEnqueue = (procId) => (rootTask) => {
  if (__Basics_isDebug && _Scheduler_queue.some((p) => p[0].a.__$id === procId.a.__$id)) {
    __Debug_crash(
      12,
      __Debug_runtimeCrashReason(`procIdAlreadyInQueue`),
      procId && procId.a && procId.a.__$id
    );
  }
  _Scheduler_queue.push([procId, rootTask]);
  if (_Scheduler_working) {
    return procId;
  }
  _Scheduler_working = true;
  while (true) {
    const next = _Scheduler_queue.shift();
    if (next === undefined) {
      _Scheduler_working = false;
      return procId;
    }
    const [newProcId, newRootTask] = next;
    if (!_Scheduler_doNotStep.has(newProcId)) {
      _Scheduler_tryAbortForProcesses.set(
        newProcId,
        A2(__RawScheduler_stepper, newProcId, newRootTask)
      );
    }
  }
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
