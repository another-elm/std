/*

import Platform.Scheduler as NiceScheduler exposing (succeed, binding, rawSpawn)
import Maybe exposing (Just, Nothing)
import Elm.Kernel.Debug exposing (crash)
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

function _Scheduler_succeed(value)
{
	return __NiceScheduler_succeed(value);
}

function _Scheduler_binding(callback)
{
	return __NiceScheduler_binding(callback);
}

function _Scheduler_rawSpawn(task)
{
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

var _Scheduler_registerNewProcess = F3((procId, procState) => {
	/**__DEBUG/
	if (_Scheduler_processes.has(procId)) {
		__Debug_crash(12, 'procIdAlreadyRegistered', procId && procId.a && procId.a.__$id);
	}
	//*/
	_Scheduler_processes.set(procId, procState);
	return procId;
});


// var _Scheduler_mailboxAdd = F2((message, procId) => {
// 	const mailbox = _Scheduler_mailboxes.get(procId);
// 	/**__DEBUG/
// 	if (mailbox === undefined) {
// 		__Debug_crash(12, 'procIdNotRegistered', procId && procId.a && procId.a.__$id);
// 	}
// 	//*/
// 	mailbox.push(message);
// 	return procId;
// });

// const _Scheduler_mailboxReceive = F2((procId, state) => {
// 	const receiver = _Scheduler_receivers.get(procId);
// 	const mailbox = _Scheduler_mailboxes.get(procId);
// 	/**__DEBUG/
// 	if (receiver === undefined || mailbox === undefined) {
// 		__Debug_crash(12, 'procIdNotRegistered', procId && procId.a && procId.a.__$id);
// 	}
// 	//*/
// 	const msg = mailbox.shift();
// 	if (msg === undefined) {
// 		return __Maybe_Nothing;
// 	} else {
// 		return __Maybe_Just(A2(receiver, msg, state));
// 	}
// });

var _Scheduler_working = false;
var _Scheduler_queue = [];

var _Scheduler_enqueueWithStepper = F2(function(stepper, procId)
{
	_Scheduler_queue.push(procId);
	if (_Scheduler_working)
	{
		return procId;
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


const _Scheduler_runOnNextTick = F2((callback, val) => {
	Promise.resolve(val).then(callback);
	return _Utils_Tuple0;
});


// CHANNELS

const _Scheduler_channels = new WeakMap();
const _Scheduler_wakers = new WeakMap();

const _Scheduler_rawRecv = F3((channelId, tryAbortAction, doneCallback) => {
	const channel = _Scheduler_channels.get(channelId);
	/**__DEBUG/
	if (channel === undefined) {
		__Debug_crash(12, 'channelIdNotRegistered', channelId && channelId.a && channelId.a.__$id);
	}
	//*/
	const msg = channel.shift();
	if (msg === undefined) {
		const waker = _Scheduler_wakers.get(channelId);
		/**__DEBUG/
		if (waker === undefined) {
			__Debug_crash(12, 'channelIdNotRegistered', channelId && channelId.a && channelId.a.__$id);
		}
		//*/
		const onWake = msg => doneCallback(msg);
		waker.add(onWake);
		return x => {
			waker.delete(onWake);
			return x;
		};
	} else {
		doneCallback(msg);
		return _ => {
			/**__DEBUG/
			__Debug_crash(12, 'abortCompletedAsyncAction');
			//*/
		};
	}
});
