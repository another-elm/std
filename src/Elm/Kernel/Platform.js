/*

import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.Json exposing (run, wrap, unwrap, errorToString)
import Elm.Kernel.List exposing (Cons, Nil)
import Elm.Kernel.Utils exposing (Tuple0)
import Result exposing (isOk)

*/

// State

var _Platform_outgoingPorts = {};
var _Platform_incomingPorts = {};
var _Platform_effectManagers = {};

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

	const dispatch = (model, cmds) => {
		const dispatcher = A2(
			functions.__$dispatchEffects,
			cmds,
			impl.__$subscriptions(model)
		);

		for (const key in managers) {
			// console.log(managers[key]);
			A2(dispatcher, key, managers[key]);
		}
	}

	const sendToApp = F2((msg, viewMetadata) => {
		const updateValue = A2(impl.__$update, msg, model);
		model = updateValue.a
		A2(stepper, model, viewMetadata);
		dispatch(model, updateValue.b);
	});

	const managers = {};
	const ports = {};
	for (const [key, {__setup}] of Object.entries(_Platform_effectManagers)) {
		managers[key] = __setup(functions.__$setupEffects, sendToApp);
	}
	for (const [key, setup] of Object.entries(_Platform_outgoingPorts)) {
		const {port, manager} = setup(
			functions.__$setupOutgoingPort,
			sendToApp
		);
		ports[key] = port;
		managers[key] = manager;
	}
	for (const [key, setup] of Object.entries(_Platform_incomingPorts))
	{
		const {port, manager} = setup(
			functions.__$setupIncomingPort,
			sendToApp
		);
		ports[key] = port;
		managers[key] = manager;
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
 * This function will **always** be call right after page load.
 */
function _Platform_createManager(init, onEffects, onSelfMsg, cmdMap, subMap)
{
	const make_setup = fullOnEffects => (setup, sendToApp) => {
		return A4(setup, sendToApp, init, fullOnEffects, onSelfMsg)
	}
	if (cmdMap === undefined) {
		// Subscription only effect module
		return {
			__cmdMapper: F2((_1, _2) => __Debug_crash(12, 'cmdMap')),
			__subMapper: subMap,
			__setup: make_setup(F4(function(router, _cmds, subs, state) {
				return A3(onEffects, router, subs, state);
			})),
		};
	} else if (subMap === undefined) {
		// Command only effect module
		return {
			__cmdMapper: cmdMap,
			__subMapper: F2((_1, _2) => __Debug_crash(12, 'subMap')),
			__setup: make_setup(F4(function(router, cmds, _subs, state) {
				return A3(onEffects, router, cmds, state);
			})),
		};
	} else {
		// Command **and** subscription event manager
		return {
			__cmdMapper: cmdMap,
			__subMapper: subMap,
			__setup: make_setup(onEffects),
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
		$: tag,
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
	_Platform_outgoingPorts[name] = function(setup, sendToApp) {
		let subs = [];

		function subscribe(callback)
		{
			subs.push(callback);
		}

		function unsubscribe(callback)
		{
			// copy subs into a new array in case unsubscribe is called within
			// a subscribed callback
			subs = subs.slice();
			var index = subs.indexOf(callback);
			if (index >= 0)
			{
				subs.splice(index, 1);
			}
		}

		const outgoingPortSend = payload => {
			const value = __Json_unwrap(converter(payload));
			for (const sub of subs)
			{
				sub(value);
			}
			return __Utils_Tuple0;
		};


		const manager = A2(
			setup,
			sendToApp,
			outgoingPortSend
		);

		return {
			port: {
				subscribe,
				unsubscribe,
			},
			manager,
		}
	}

	return _Platform_leaf(name)
}


function _Platform_incomingPort(name, converter)
{
	_Platform_checkPortName(name);
	_Platform_incomingPorts[name] = function(setup, sendToApp) {
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
	}

	return _Platform_leaf(name)
}


// Functions exported to elm


const _Platform_effectManagerNameToString = name => name;


const _Platform_getCmdMapper = home => {
	if (_Platform_outgoingPorts.hasOwnProperty(home)) {
		return F2((_tagger, value) => value);
	}
	return _Platform_effectManagers[home].__cmdMapper;
};


const _Platform_getSubMapper = home => {
	if (_Platform_incomingPorts.hasOwnProperty(home)) {
		return F2((tagger, finalTagger) => value => tagger(finalTagger(value)));
	}
	return _Platform_effectManagers[home].__subMapper;
};


const _Platform_crashOnEarlyMessage = F2((_1, _2) =>
	__Debug_crash(12, 'earlyMsg')
);



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
