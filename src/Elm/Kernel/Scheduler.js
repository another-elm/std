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

function _Scheduler_binding(callback) {
  return __NiceScheduler_binding(callback);
}

function _Scheduler_rawSpawn(task) {
  return __NiceScheduler_rawSpawn(task);
}

// SCHEDULER

var _Scheduler_guid = 0;
var _Scheduler_processes = new WeakMap();
var _Scheduler_readyFlgs = new WeakMap();

function _Scheduler_getGuid() {
  return _Scheduler_guid++;
}

function _Scheduler_getProcessState(id) {
  const procState = _Scheduler_processes.get(id);
	if (__Basics_isDebug && procState === undefined) {
		__Debug_crash(12, __Debug_runtimeCrashReason('procIdNotRegistered'), id && id.a && id.a.__$id);
	}
  return procState;
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

  const stepProccessWithId = (newProcId) => {
    const procState = _Scheduler_processes.get(newProcId);
    if (__Basics_isDebug && procState === undefined) {
      __Debug_crash(
        12,
        __Debug_runtimeCrashReason("procIdNotRegistered"),
        newProcId && newProcId.a && newProcId.a.__$id
      );
    }
    const updatedState = A2(stepper, newProcId, procState);
    if (__Basics_isDebug && procState !== _Scheduler_processes.get(newProcId)) {
      __Debug_crash(
        12,
        __Debug_runtimeCrashReason("reentrantProcUpdate"),
        newProcId && newProcId.a && newProcId.a.__$id
      );
    }
    _Scheduler_processes.set(newProcId, updatedState);
  };

  return (procId) => {
    if (__Basics_isDebug && queue.some((p) => p.a.__$id === procId.a.__$id)) {
      __Debug_crash(
        12,
        __Debug_runtimeCrashReason("procIdAlreadyInQueue"),
        procId && procId.a && procId.a.__$id
      );
    }
    queue.push(procId);
    if (working) {
      return procId;
    }
    working = true;
    while (true) {
      const newProcId = queue.shift();
      if (newProcId === undefined) {
        working = false;
        return procId;
      }
      stepProccessWithId(newProcId);
    }
  };
};

var _Scheduler_delay = F3(function (time, value, callback) {
  var id = setTimeout(function () {
    callback(value);
  }, time);

  return function (x) {
    clearTimeout(id);
    return x;
  };
});

const _Scheduler_getWokenValue = (procId) => {
  const flag = _Scheduler_readyFlgs.get(procId);
  if (flag === undefined) {
    return __Maybe_Nothing;
  } else {
    _Scheduler_readyFlgs.delete(procId);
    return __Maybe_Just(flag);
  }
};

const _Scheduler_setWakeTask = F2((procId, newRoot) => {
	if (__Basics_isDebug && _Scheduler_readyFlgs.has(procId)) {
		__Debug_crash(
			12,
			__Debug_runtimeCrashReason('procIdAlreadyReady'),
			procId && procId.a && procId.a.__$id,
			_Scheduler_readyFlgs.get(procId)
		);
	}
  _Scheduler_readyFlgs.set(procId, newRoot);
  return _Utils_Tuple0;
});
