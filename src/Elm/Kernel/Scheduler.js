/*

import Platform.Scheduler as NiceScheduler exposing (succeed, binding)

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
	return Object.create({ id: _Scheduler_guid++ });
}

function _Scheduler_getProcessState(id) {
	const procState = _Scheduler_processes.get(id);
	/**__DEBUG/
	if (procState === undefined) {
		console.error(`INTERNAL ERROR: Process with id ${id} is not in map!`);
	}
	//*/
	return procState;
}

var _Scheduler_updateProcessState = F2((func, id) => {
	const procState = _Scheduler_getProcessState.get(id);
	_Scheduler_processes.set(id, func(procState));
	return procState;
});

var _Scheduler_registerNewProcess = F2((procId, procState) => {
	/**__DEBUG/
	if (_Scheduler_processes.has(procId)) {
		console.error(`INTERNAL ERROR: Process with id ${id} is already in map!`);
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
	while (procId = _Scheduler_queue.shift())
	{
		stepper(procId);
	}
	_Scheduler_working = false;
	return procId;
});


var _Scheduler_delay = F3(function (time, value, callback)
{
	var id = setTimeout(function() {
		callback(value);
	}, time);

	return function(x) { clearTimeout(id); return x; };
});
