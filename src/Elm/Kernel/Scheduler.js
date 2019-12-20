/*

import Platform.Scheduler as NiceScheduler exposing (succeed, binding)
import Elm.Kernel.Debug exposing (crash)
*/

// COMPATIBILITY

/*
 * We include these to avoid having to change code
 * in other `elm/*` packages.
 *
 * We have to define these as functions rather than
 * variables as the implementations of
 * elm/core:Platform.Scheduler.* functions may come
 * later in the generated javascript file.
 */

function _Scheduler_succeed(value)
{
	return __NiceScheduler_succeed(value);
}

function _Scheduler_binding(callback)
{
	return __NiceScheduler_binding(callback);
}

// SCHEDULER


var _Scheduler_guid = 0;
var _Scheduler_processes = new WeakMap();

function _Scheduler_getGuid() {
	return _Scheduler_guid++;
}

function _Scheduler_getProcessState(id) {
	const procState = _Scheduler_processes.get(id);
	/**__DEBUG/
	if (procState === undefined) {
		__Debug_crash(12, 'procIdNotRegistered', id && id.a && id.a.id);
	}
	//*/
	return procState;
}

var _Scheduler_updateProcessState = F2((func, id) => {
	const procState = _Scheduler_processes.get(id);
	/**__DEBUG/
	if (procState === undefined) {
		__Debug_crash(12, 'procIdNotRegistered', id && id.a && id.a.__$id);
	}
	//*/
	const updatedState = func(procState);
	/**__DEBUG/
	if (procState !==  _Scheduler_processes.get(id)) {
		__Debug_crash(12, 'reentrantProcUpdate', id && id.a && id.a.__$id);
	}
	//*/
	_Scheduler_processes.set(id, updatedState);
	return procState;
});

var _Scheduler_registerNewProcess = F2((procId, procState) => {
	// console.log("registering", procId);
	/**__DEBUG/
	if (procState === undefined) {
		__Debug_crash(12, 'procIdAlreadyRegistered', procId && procId.a && procId.a.__$id);
	}
	//*/
	_Scheduler_processes.set(procId, procState);
	return procId;
});


var _Scheduler_working = false;
var _Scheduler_queue = [];

var _Scheduler_enqueueWithStepper = F2(function(stepper, procId)
{
	_Scheduler_queue.push(procId);
	if (_Scheduler_working)
	{
		return;
	}
	_Scheduler_working = true;
	while (true)
	{
		const newProcId = _Scheduler_queue.shift();
		if (newProcId === undefined) {
			_Scheduler_working = false;
			return procId;
		}
		stepper(newProcId);
	}
});


var _Scheduler_delay = F3(function (time, value, callback)
{
	var id = setTimeout(function() {
		callback(value);
	}, time);

	return function(x) { clearTimeout(id); return x; };
});
