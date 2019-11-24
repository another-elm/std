/*

import Elm.Kernel.Utils exposing (Tuple0)

*/


// TASKS

function _Scheduler_succeed(value)
{
	/**__DEBUG/
	return {
		$: 'Succeed',
		a: value
	};
	//*/

	/**__PROD/
	return {
		$: 0,
		a: value
	};
	//*/
}

function _Scheduler_fail(error)
{
	/**__DEBUG/
	return {
		$: 'Fail',
		a: error
	};
	//*/

	/**__PROD/
	return {
		$: 1,
		a: error
	};
	//*/
}

function _Scheduler_binding(callback, killable)
{
	/**__DEBUG/
	return {
		$: 'Binding',
		a: killable
			? function(x) {
				return {
					$: 'Just',
					a: callback(x),
				};
			}
			: function(x) {
				callback(x);
				return {
					$: 'Nothing',
				}
			}
		b: {$: 'Nothing'}
	};
	//*/

	/**__PROD/
	return {
		$: 2,
		a: killable
			? function(x) {
				return {
					$: 0,
					a: callback(x),
				};
			}
			: function(x) {
				callback(x);
				return {
					$: 1,
				}
			}
		b: {$: 1}
	};
	//*/
}

var _Scheduler_andThen = F2(function(callback, task)
{
	/**__DEBUG/
	return {
		$: 'AndThen',
		a: callback
		b: task
	};
	//*/

	/**__PROD/
	return {
		$: 3,
		a: callback
		b: task
	};
	//*/
});

var _Scheduler_onError = F2(function(callback, task)
{
	/**__DEBUG/
	return {
		$: 'OnError',
		a: callback
		b: task
	};
	//*/

	/**__PROD/
	return {
		$: 4,
		a: callback
		b: task
	};
	//*/
});

function _Scheduler_receive(callback)
{
	/**__DEBUG/
	return {
		$: 'Receive',
		a: callback
	};
	//*/

	/**__PROD/
	return {
		$: 5,
		a: callback
	};
	//*/
}


// PROCESSES

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

function _Scheduler_updateProcessState(func, id) {
	const procState = _Scheduler_getProcessState.get(id);
	_Scheduler_processes.set(id, func(procState));
	return procState;
}

function _Scheduler_registerNewProcess(procId, procState) {
	/**__DEBUG/
	if (_Scheduler_processes.has(procId)) {
		console.error(`INTERNAL ERROR: Process with id ${id} is already in map!`);
	}
	//*/
	_Scheduler_processes.set(procId, procState);
	return procId;
}


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

