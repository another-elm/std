/*

import Platform.Scheduler as NiceScheduler exposing (succeed, binding, rawSpawn)
import Maybe exposing (Just, Nothing)
import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.Utils exposing (Tuple0, Tuple2)
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
		__Debug_crash(12, 'procIdNotRegistered', id && id.a && id.a.__$id);
	}
	//*/
	return procState;
}


var _Scheduler_registerNewProcess = F2((procId, procState) => {
	/**__DEBUG/
	if (_Scheduler_processes.has(procId)) {
		__Debug_crash(12, 'procIdAlreadyRegistered', procId && procId.a && procId.a.__$id);
	}
	//*/
	_Scheduler_processes.set(procId, procState);
	return procId;
});



const _Scheduler_enqueueWithStepper = stepper => {
	let working = false;
	const queue = [];

	const stepProccessWithId = newProcId => {
		const procState = _Scheduler_processes.get(newProcId);
		/**__DEBUG/
		if (procState === undefined) {
			__Debug_crash(12, 'procIdNotRegistered', newProcId && newProcId.a && newProcId.a.__$id);
		}
		//*/
		const updatedState = A2(stepper, newProcId, procState);
		/**__DEBUG/
		if (procState !== _Scheduler_processes.get(newProcId)) {
			__Debug_crash(12, 'reentrantProcUpdate', newProcId && newProcId.a && newProcId.a.__$id);
		}
		//*/
		_Scheduler_processes.set(newProcId, updatedState);
	};

	return procId => {
		/**__DEBUG/
		if (queue.some(p => p.a.__$id === procId.a.__$id)) {
			__Debug_crash(12, 'procIdAlreadyInQueue', procId && procId.a && procId.a.__$id);
		}
		//*/
		queue.push(procId);
		if (working)
		{
			return procId;
		}
		working = true;
		while (true)
		{
			const newProcId = queue.shift();
			if (newProcId === undefined) {
				working = false;
				return procId;
			}
			stepProccessWithId(newProcId);
		}
	};
};


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
		__Debug_crash(
			12,
			'procIdAlreadyReady',
			procId && procId.a && procId.a.__$id,
			_Scheduler_readyFlgs.get(procId)
		);
	}
	//*/
	_Scheduler_readyFlgs.set(procId, newRoot);
	return _Utils_Tuple0;
});


// CHANNELS

const _Scheduler_channels = new WeakMap();
let _Scheduler_channelId = 0;

const _Scheduler_rawUnbounded = _ => {
	const id = {
		id: _Scheduler_channelId++
	};
	_Scheduler_channels.set(id, {
		messages: [],
		wakers: new Set(),
	});
	return _Utils_Tuple2(_Scheduler_rawSend(id), id);
}

const _Scheduler_setWaker = F2((channelId, onMsg) => {
	const channel = _Scheduler_channels.get(channelId);
	/**__DEBUG/
	if (channel === undefined) {
		__Debug_crash(12, 'channelIdNotRegistered', channelId && channelId.a && channelId.a.__$id);
	}
	//*/
	const onWake = msg => {
		return onMsg(msg);
	}
	channel.wakers.add(onWake);
	return x => {
		channel.wakers.delete(onWake);
		return x;
	};
});


const _Scheduler_rawTryRecv = (channelId) => {
	const channel = _Scheduler_channels.get(channelId);
	/**__DEBUG/
	if (channel === undefined) {
		__Debug_crash(12, 'channelIdNotRegistered', channelId && channelId.a && channelId.a.__$id);
	}
	//*/
	const msg = channel.messages.shift();
	if (msg === undefined) {
		return __Maybe_Nothing;
	} else {
		return __Maybe_Just(msg);
	}
};


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
		channel.wakers.delete(nextWaker);
		nextWaker(msg);
	}
	return _Utils_Tuple0;
});
