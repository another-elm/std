/*

import Platform.Unstable.Scheduler as RawScheduler exposing (stepper)
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
 * Any code using these is probably broken!
 */

function _Scheduler_succeed() {
  throw new Error("not implemented");
}

function _Scheduler_binding() {
  throw new Error("not implemented");
}

function _Scheduler_rawSpawn() {
  throw new Error("not implemented");
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
  // todo(harry): abstract this into elm somehow.
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
  for (;;) {
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

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Scheduler_.*" }] */

/* global __RawScheduler_stepper */
/* global __Debug_crash, __Debug_runtimeCrashReason */
/* global __Basics_isDebug */
/* global __Utils_Tuple0 */
