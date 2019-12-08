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
var _Platform_compiledEffectManagers = {};

// INITIALIZE A PROGRAM


function _Platform_initialize(flagDecoder, args, impl, functions)
{
	// Elm.Kernel.Json.wrap : RawJsObject -> Json.Decode.Value
	// Elm.Kernel.Json.run : Json.Decode.Decoder a -> Json.Decode.Value -> Result Json.Decode.Error a
	const flagsResult = A2(__Json_run, flagDecoder, __Json_wrap(args ? args['flags'] : undefined));

	if (!__Result_isOk(flagsResult)) {
		__Debug_crash(2 /**__DEBUG/, __Json_errorToString(result.a) /**/);
	}

	const managers = {};
	const ports = {};
	const initValue = impl.__$init(flagsResult.a);
	var model = initValue.a;
	const stepper = A2(functions.__$stepperBuilder, sendToApp, model);

	for (var key in _Platform_effectManagers)
	{
		const setup = _Platform_effectManagers[key];
		_Platform_compiledEffectManagers[key] =
			setup(functions.__$setupEffects, sendToApp);
		managers[key] = setup;
	}
	for (var key in _Platform_outgoingPorts)
	{
		const setup = _Platform_outgoingPorts[key];
		_Platform_compiledEffectManagers[key] =
			setup(functions.__$setupOutgoingPort, sendToApp);
		ports[key] = setup.ports;
		managers[key] = setup.manger;
	}
	for (var key in _Platform_incomingPorts)
	{
		const setup = _Platform_incomingPorts[key];
		_Platform_compiledEffectManagers[key] =
			setup(functions.__$setupIncomingPort, sendToApp);
		ports[key] = setup.ports;
		managers[key] = setup.manger;
	}

	const sendToApp = F2((msg, viewMetadata) => {
		const updateValue = A2(impl.__$update, msg, model);
		model = updateValue.a
		A2(stepper, model, viewMetadata);
		A3(functions.__$dispatchEffects, managers, updateValue.b, impl.__$subscriptions(model));
	})

	A3(functions.__$dispatchEffects, managers, updateValue.b, impl.__$subscriptions(model));

	return ports ? { ports: ports } : {};
}



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



function _Platform_getEffectManager(name) {
	return _Platform_compiledEffectManagers[name];
}

function _Platform_effectManagerNameToString(name) {
	return name;
}


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
		fullCmdMap = F2(function(tagger, _val) {
			/**__DEBUG/
			if (procState === undefined) {
				console.error(`INTERNAL ERROR: attempt to map Cmd for subscription only effect module!`);
			}
			//*/
		});
		fullSubMap = subMap;
	} else if (subMap === undefined) {
		// Command only effect module
		fullOnEffects = F4(function(router, cmds, subs, state) {
			return A3(onEffects, router, cmds, state);
		});
		fullCmdMap = cmdMap;
		fullSubMap = F2(function(tagger, _val) {
			/**__DEBUG/
			if (procState === undefined) {
				console.error(`INTERNAL ERROR: attempt to map Sub for command only effect module!`);
			}
			//*/
		});
	} else {
		fullOnEffects = onEffects;
		fullCmdMap = cmdMap;
		fullSubMap = subMap;
	}
	// Command **and** subscription event manager
	return function(setup, sendToApp) {
		return A6(setup, sendToApp, init, fullOnEffects, onSelfMsg, fullCmdMap, fullSubMap)
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
					a: {
						$: __1_EFFECTMANAGERNAME,
						a: home
					},
					b: {
						$: __2_LEAFTYPE,
						a: value
					},
					c: _Platform_compiledEffectManagers[home].__$cmdMap,
					d: _Platform_compiledEffectManagers[home].__$subMap
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
					a: {
						$: __1_EFFECTMANAGERNAME,
						a: home
					},
					b: {
						$: __2_LEAFTYPE,
						a: value
					},
					c: _Platform_compiledEffectManagers[home].__$cmdMap,
					d: _Platform_compiledEffectManagers[home].__$subMap
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
	if (_Platform_compiledEffectManagers[name])
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
			var value = __Json_unwrap(payload);
			for (const sub of subs)
			{
				sub(value);
			}
			return __Utils_Tuple0;
		};


		const manager = A3(
			setup,
			sendToApp,
			outgoingPortSend,
			{
				subscribe: subscribe,
				unsubscribe: unsubscribe
			},
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
