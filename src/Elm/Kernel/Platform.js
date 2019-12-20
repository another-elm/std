/*

import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.Json exposing (run, wrap, unwrap, errorToString)
import Elm.Kernel.List exposing (Nil)
import Elm.Kernel.Utils exposing (Tuple0)
import Result exposing (isOk)

*/

// State

var _Platform_outgoingPorts = {};
var _Platform_incomingPorts = {};
var _Platform_effectManagers = {};

const _Platform_cmdMappers = {};
const _Platform_subMappers = {};

// INITIALIZE A PROGRAM

const _Platform_initialize = F4((flagDecoder, args, impl, functions) => {

	// Elm.Kernel.Json.wrap : RawJsObject -> Json.Decode.Value
	// Elm.Kernel.Json.run : Json.Decode.Decoder a -> Json.Decode.Value -> Result Json.Decode.Error a
	const flagsResult = A2(__Json_run, flagDecoder, __Json_wrap(args ? args['flags'] : undefined));

	if (!__Result_isOk(flagsResult)) {
		__Debug_crash(2 /**__DEBUG/, __Json_errorToString(result.a) /**/);
	}

	const sendToApp = F2((msg, viewMetadata) => {
		const updateValue = A2(impl.__$update, msg, model);
		model = updateValue.a
		A2(stepper, model, viewMetadata);

		const dispatcher = A2(functions.__$dispatchEffects, updateValue.b, impl.__$subscriptions(model));

		for (const key in managers) {
			// console.log(managers[key]);
			A2(dispatcher, key, managers[key]);
		}
	});

	const managers = {};
	const ports = {};

	const initValue = impl.__$init(flagsResult.a);
	let model = initValue.a;
	const stepper = A2(functions.__$stepperBuilder, sendToApp, model);

	for (var key in _Platform_effectManagers)
	{
		const setup = _Platform_effectManagers[key].__setup;
		managers[key] = setup(functions.__$setupEffects, sendToApp);
	}
	for (var key in _Platform_outgoingPorts)
	{
		const setup = _Platform_outgoingPorts[key](functions.__$setupOutgoingPort, sendToApp);
		ports[key] = setup.ports;
		managers[key] = setup.manager;
	}
	for (var key in _Platform_incomingPorts)
	{
		const setup = _Platform_incomingPorts[key](functions.__$setupIncomingPort, sendToApp);
		ports[key] = setup.ports;
		managers[key] = setup.manager;
	}
	// console.log('managers', managers);
	const dispatcher = A2(functions.__$dispatchEffects, initValue.b, impl.__$subscriptions(model));

	for (const key in managers) {
		// console.log(managers[key]);
		A2(dispatcher, key, managers[key]);
	}

	return ports ? { ports: ports } : {};
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


function _Platform_effectManagerNameToString(name) {
	// console.log("effect to string", name);
	return name;
}

const _Platform_subOnlyCmdMap = F2(function(_1, _2) {
	/**__DEBUG/
	if (procState === undefined) {
		__Debug_crash(12, 'cmdMap');
	}
	//*/
});

const _Platform_cmdOnlySubMap = F2(function(_1, _2) {
	/**__DEBUG/
	if (procState === undefined) {
		__Debug_crash(12, 'subMap');
	}
	//*/
});


const _Platform_getCmdMapper = home => {
	if (_Platform_outgoingPorts.hasOwnProperty(home)) {
		return F2((_tagger, value) => value);
	}
	return _Platform_effectManagers[home].__cmdMapper;
};


const _Platform_getSubMapper = F2(function(portSubMapper, home) {
	if (_Platform_incomingPorts.hasOwnProperty(home)) {
		return F2((tagger, finalTagger) => value => tagger(finalTagger(value)));
	}
	return _Platform_effectManagers[home].__subMapper;
});


// Called by compiler generated js when creating event mangers
function _Platform_createManager(init, onEffects, onSelfMsg, cmdMap, subMap)
{
	// TODO(harry) confirm this is valid
	let fullOnEffects, fullCmdMap, fullSubMap;
	if (cmdMap === undefined) {
		// Subscription only effect module
		fullOnEffects = F4(function(router, cmds, subs, state) {
			return A3(onEffects, router, subs, state);
		});
		fullCmdMap = _Platform_subOnlyCmdMap;
		_Platform = subMap;
	} else if (subMap === undefined) {
		// Command only effect module
		fullOnEffects = F4(function(router, cmds, subs, state) {
			return A3(onEffects, router, cmds, state);
		});
		fullCmdMap = cmdMap;
		fullSubMap = _Platform_cmdOnlySubMap;
	} else {
		fullOnEffects = onEffects;
		fullCmdMap = cmdMap;
		fullSubMap = subMap;
	}

	// Command **and** subscription event manager
	return {
		__cmdMapper: fullCmdMap,
		__subMapper: fullSubMap,
		__setup: function(setup, sendToApp) {
			return A4(setup, sendToApp, init, fullOnEffects, onSelfMsg)
		}
	};
}

// BAGS


/* Called by compiler generated js for event managers for the
 * `command` or `subscription` function within an event manager
 */
function _Platform_leaf(home)
{
	return function(value)
	{
		/**__DEBUG/
		return {
			$: 'Data',
			a: {
				$: '::',
				a: {
					__$home: home,
					__$value: value
				},
				b: {
					$: '[]'
				}
			}
		};
		//*/

		/**__PROD/
		return {
			$: ,
			a: {
				$: 1,
				a: {
					__$home: home,
					__$value: value
				},
				b: {
					$: 0
				}
			}
		};
		//*/
	};
}


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
			// copy subs into a new array in case unsubscribe is called within a
			// subscribed callback
			subs = subs.slice();
			var index = subs.indexOf(callback);
			if (index >= 0)
			{
				subs.splice(index, 1);
			}
		}

		const outgoingPortSend = payload => {
			var value = __Json_unwrap(converter(payload));
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
			ports: {
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
			ports: {
				send,
			},
			manager: setupTuple.a,
		}
	}

	return _Platform_leaf(name)
}



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
