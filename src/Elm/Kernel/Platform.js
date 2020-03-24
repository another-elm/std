/*

import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.Json exposing (run, wrap, unwrap, errorToString)
import Elm.Kernel.List exposing (Cons, Nil)
import Elm.Kernel.Utils exposing (Tuple0)
import Result exposing (isOk)
import Platform exposing (Task, ProcessId)
import Platform.Effects as Effects exposing (mapCommand)
import Platform.Scheduler as Scheduler exposing (binding, succeed)

*/

// State

var _Platform_outgoingPorts = new Map();
var _Platform_incomingPorts = new Map();
var _Platform_effectManagers = {};

var _Platform_effectsQueue = [];
var _Platform_effectDispatchInProgress = false;

// INITIALIZE A PROGRAM

const _Platform_initialize = F4((flagDecoder, args, impl, functions) => {

	// Elm.Kernel.Json.wrap : RawJsObject -> Json.Decode.Value
	// Elm.Kernel.Json.run : Json.Decode.Decoder a -> Json.Decode.Value -> Result Json.Decode.Error a
	const flagsResult = A2(
		__Json_run,
		flagDecoder,
		__Json_wrap(args ? args['flags'] : undefined)
	);

	if (!__Result_isOk(flagsResult)) {
		__Debug_crash(2 /**__DEBUG/, __Json_errorToString(result.a) /**/);
	}

	const selfSenders = new Map();
	const ports = {};

	const dispatch = (model, cmds) => {
		_Platform_effectsQueue.push({
			__cmds: cmds,
			__subs: impl.__$subscriptions(model),
		});

		if (_Platform_effectDispatchInProgress) {
			return;
		}

		_Platform_effectDispatchInProgress = true;
		while (true) {
			const fx = _Platform_effectsQueue.shift();
			if (fx === undefined) {
				_Platform_effectDispatchInProgress = false;
				return;
			}
			const dispatcher = A2(
				functions.__$dispatchEffects,
				fx.__cmds,
				fx.__subs,
			);
			for (const [key, selfSender] of selfSenders.entries()) {
				A2(dispatcher, key, selfSender);
			}
		}
	}

	const sendToApp = F2((msg, viewMetadata) => {
		const updateValue = A2(impl.__$update, msg, model);
		model = updateValue.a
		A2(stepper, model, viewMetadata);
		dispatch(model, updateValue.b);
	});

	selfSenders.set('000PlatformEffect', functions.__$setupEffectsChannel(sendToApp));
	for (const [key, effectManagerFunctions] of Object.entries(_Platform_effectManagers)) {
		const manager = A4(
			functions.__$setupEffects,
			sendToApp,
			effectManagerFunctions.__init,
			effectManagerFunctions.__fullOnEffects,
			effectManagerFunctions.__onSelfMsg
		);
		selfSenders.set(key, manager);
	}
	for (const [key, {port, outgoingPortSend}] of _Platform_outgoingPorts.entries()) {
		ports[key] = port;
	}
	for (const [key, setup] of _Platform_incomingPorts.entries())	{
		const {port, manager} = setup(
			functions.__$setupIncomingPort,
			sendToApp
		);
		ports[key] = port;
		selfSenders.set(key, manager);
	}

	const initValue = impl.__$init(flagsResult.a);
	let model = initValue.a;
	const stepper = A2(functions.__$stepperBuilder, sendToApp, model);

	dispatch(model, initValue.b);

	return ports ? { ports } : {};
});


// TRACK PRELOADS
//
// This is used by code in elm/browser and elm/http
// to register any HTTP requests that are triggered by init.
//


var _Platform_preload;


function _Platform_registerPreload(url)
{
	_Platform_preload.add(url);
}


// EFFECT MANAGERS


/* Called by compiler generated js when creating event mangers.
 *
 * This function will **always** be call right after page load like this:
 *
 * 		_Platform_effectManagers['XXX'] =
 * 			_Platform_createManager($init, $onEffects, $onSelfMsg, $cmdMap);
 *
 * or
 *
 * 		_Platform_effectManagers['XXX'] =
 * 			_Platform_createManager($init, $onEffects, $onSelfMsg, 0, $subMap);
 *
 * or
 *
 * 		_Platform_effectManagers['XXX'] =
 * 			_Platform_createManager($init, $onEffects, $onSelfMsg, $cmdMap, $subMap);
 */
function _Platform_createManager(init, onEffects, onSelfMsg, cmdMap, subMap)
{
	if (typeof cmdMap !== 'function') {
		// Subscription only effect module
		return {
			__cmdMapper: F2((_1, _2) => __Debug_crash(12, 'cmdMap')),
			__subMapper: subMap,
			__init: init,
			__fullOnEffects: F4(function(router, _cmds, subs, state) {
				return A3(onEffects, router, subs, state);
			}),
			__onSelfMsg: onSelfMsg,
		};
	} else if (typeof subMap !==  'function') {
		// Command only effect module
		return {
			__cmdMapper: cmdMap,
			__subMapper: F2((_1, _2) => __Debug_crash(12, 'subMap')),
			__init: init,
			__fullOnEffects: F4(function(router, cmds, _subs, state) {
				return A3(onEffects, router, cmds, state);
			}),
			__onSelfMsg: onSelfMsg
		};
	} else {
		// Command **and** subscription event manager
		return {
			__cmdMapper: cmdMap,
			__subMapper: subMap,
			__init: init,
			__fullOnEffects: onEffects,
			__onSelfMsg: onSelfMsg
		};
	}
}

// BAGS

/* Called by compiler generated js for event managers for the
 * `command` or `subscription` function within an event manager
 */
const _Platform_leaf = home => value => {
	const list = __List_Cons({
		__$home: home,
		__$value: value
	}, __List_Nil);
	/**__DEBUG/
	return {
		$: 'Data',
		a: list,
	};
	/**/
	/**__PROD/
	return list;
	/**/
};


// PORTS


function _Platform_checkPortName(name)
{
	if (_Platform_effectManagers[name])
	{
		__Debug_crash(3, name)
	}
}


function _Platform_outgoingPort(name, converter)
{
	_Platform_checkPortName(name);
	let subs = [];
	const subscribe = callback => {
		subs.push(callback);
	};
	const unsubscribe = callback => {
		// copy subs into a new array in case unsubscribe is called within
		// a subscribed callback
		subs = subs.slice();
		var index = subs.indexOf(callback);
		if (index >= 0)
		{
			subs.splice(index, 1);
		}
	};
	const execSubscribers = payload => {
		const value = __Json_unwrap(converter(payload));
		for (const sub of subs)
		{
			sub(value);
		}
		return __Utils_Tuple0;
	}
	_Platform_outgoingPorts.set(name, {
		port: {
			subscribe,
			unsubscribe,
		},
	});

	return payload => A2(
		_Platform_leaf,
		'000PlatformEffect',
		_ => __Scheduler_binding(doneCallback => {
			execSubscribers(payload);
			doneCallback(__Scheduler_succeed(__Utils_Tuple0));
			return x => x;
		})
	);
}


function _Platform_incomingPort(name, converter)
{
	_Platform_checkPortName(name);
	_Platform_incomingPorts.set(name, function(setup, sendToApp) {
		let subs = __List_Nil;

		function updateSubs(subsList) {
			subs = subsList;
		}

		const setupTuple = A2(setup, sendToApp, updateSubs);

		function send(incomingValue)
		{
			var result = A2(__Json_run, converter, __Json_wrap(incomingValue));

			__Result_isOk(result) || __Debug_crash(4, name, result.a);

			var value = result.a;
			A2(setupTuple.b, value, subs);
		}

		return {
			port: {
				send,
			},
			manager: setupTuple.a,
		}
	});

	return _Platform_leaf(name)
}


// Functions exported to elm


const _Platform_effectManagerNameToString = name => name;


const _Platform_getCmdMapper = home => {
	if (_Platform_outgoingPorts.has(home)) {
		return F2((_tagger, value) => value);
	}
	if (home === '000PlatformEffect') {
		return __Effects_mapCommand;
	}
	return _Platform_effectManagers[home].__cmdMapper;
};


const _Platform_getSubMapper = home => {
	if (_Platform_incomingPorts.has(home)) {
		return F2((tagger, finalTagger) => value => tagger(finalTagger(value)));
	}
	return _Platform_effectManagers[home].__subMapper;
};

const _Platform_wrapTask = task => __Platform_Task(task);

const _Platform_wrapProcessId = processId => __Platform_ProcessId(processId);

// EXPORT ELM MODULES
//
// Have DEBUG and PROD versions so that we can (1) give nicer errors in
// debug mode and (2) not pay for the bits needed for that in prod mode.
//


function _Platform_export__PROD(exports)
{
	scope['Elm']
		? _Platform_mergeExportsProd(scope['Elm'], exports)
		: scope['Elm'] = exports;
}


function _Platform_mergeExportsProd(obj, exports)
{
	for (var name in exports)
	{
		(name in obj)
			? (name == 'init')
				? __Debug_crash(6)
				: _Platform_mergeExportsProd(obj[name], exports[name])
			: (obj[name] = exports[name]);
	}
}


function _Platform_export__DEBUG(exports)
{
	scope['Elm']
		? _Platform_mergeExportsDebug('Elm', scope['Elm'], exports)
		: scope['Elm'] = exports;
}


function _Platform_mergeExportsDebug(moduleName, obj, exports)
{
	for (var name in exports)
	{
		(name in obj)
			? (name == 'init')
				? __Debug_crash(6, moduleName)
				: _Platform_mergeExportsDebug(moduleName + '.' + name, obj[name], exports[name])
			: (obj[name] = exports[name]);
	}
}
