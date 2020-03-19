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
var _Scheduler_readyFlgs = new WeakMap();

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
	if (procState !== _Scheduler_processes.get(id)) {
		__Debug_crash(12, 'reentrantProcUpdate', id && id.a && id.a.__$id);
	}
	//*/
	_Scheduler_processes.set(id, updatedState);
	return _Utils_Tuple0;
});

var _Scheduler_registerNewProcess = F2((procId, procState) => {
	/**__DEBUG/
	if (_Scheduler_processes.has(procId)) {
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


const _Scheduler_getWokenValue = procId => {
	const flag = _Scheduler_readyFlgs.get(procId);
	if (flag === undefined) {
		return __Maybe_Nothing;
	} else {
		_Scheduler_readyFlgs.delete(procId);
		return __Maybe_Just(flag);
	}
};


const _Scheduler_setWakeTask = F2((procId, newRoot) => {
	/**__DEBUG/
	if (_Scheduler_readyFlgs.has(procId)) {
		__Debug_crash(12, 'procIdAlreadyReady', procId && procId.a && procId.a.__$id);
	}
	//*/
	_Scheduler_readyFlgs.set(procId, newRoot);
	return _Utils_Tuple0;
});


// CHANNELS

const _Scheduler_channels = new WeakMap();

const _Scheduler_registerChannel = channelId => {
	_Scheduler_channels.set(channelId, {
		messages: [],
		wakers: new Set(),
	});
	return channel;
}

const _Scheduler_rawRecv = F2((channelId, onMsg) => {
	const channel = _Scheduler_channels.get(channelId);
	/**__DEBUG/
	if (channel === undefined) {
		__Debug_crash(12, 'channelIdNotRegistered', channelId && channelId.a && channelId.a.__$id);
	}
	//*/
	const msg = channel.messages.shift();
	if (msg === undefined) {
		const onWake = msg => onMsg(msg);
		channel.wakers.add(onWake);
		return x => {
			channel.wakers.delete(onWake);
			return x;
		};
	} else {
		onMsg(msg);
		return x => x;
	}
});

const _Scheduler_rawSend = F2((channelId, msg) => {
	const channel = _Scheduler_channels.get(channelId);
	/**__DEBUG/
	if (channel === undefined) {
		__Debug_crash(12, 'channelIdNotRegistered', channelId && channelId.a && channelId.a.__$id);
	}
	//*/

	const wakerIter = channel.wakers[Symbol.iterator]();
	const { value: nextWaker, done } = wakerIter.next();
	if (done) {
		channel.messages.push(msg);
	} else {
		nextWaker(msg);
	}
	return _Utils_Tuple0;
});
