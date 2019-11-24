/*

import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.Json exposing (run, wrap, unwrap, errorToString)
import Elm.Kernel.List exposing (Cons, Nil)
import Elm.Kernel.Process exposing (sleep)
import Elm.Kernel.Scheduler exposing (andThen, binding, rawSend, rawSpawn, receive, send, succeed)
import Elm.Kernel.Utils exposing (Tuple0)
import Result exposing (isOk)

*/



// PROGRAMS


var _Platform_worker = F4(function(impl, flagDecoder, debugMetadata, args)
{
	return _Platform_initialize(
		flagDecoder,
		args,
		impl.__$init,
		impl.__$update,
		impl.__$subscriptions,
		function() { return function() {} }
	);
});



// INITIALIZE A PROGRAM


function _Platform_initialize(flagDecoder, args, init, update, subscriptions, stepperBuilder)
{
	var result = A2(__Json_run, flagDecoder, __Json_wrap(args ? args['flags'] : undefined));
	__Result_isOk(result) || __Debug_crash(2 /**__DEBUG/, __Json_errorToString(result.a) /**/);
	var managers = {};
	result = init(result.a);
	var model = result.a;
	var stepper = stepperBuilder(sendToApp, model);
	var ports = _Platform_setupEffects(managers, sendToApp);

	function sendToApp(msg, viewMetadata)
	{
		result = A2(update, msg, model);
		stepper(model = result.a, viewMetadata);
		_Platform_dispatchEffects(managers, result.b, subscriptions(model));
	}

	_Platform_dispatchEffects(managers, result.b, subscriptions(model));

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


var _Platform_effectManagers = {};

var _Platform_effectMangerFold = F2(function(func, initial) {
	for (const key of  Object.items(_Platform_effectManagers)) {
		const info = _Platform_effectManagers[key];
		// TODO(harry) confirm this is valid
		let effectTag;

		if (info.__cmdMap === undefined) {
			/**__DEBUG/
			effectTag = 'SubOnlyEffectModule';
			//*/

			/**__PROD/
			effectTag = 0;
			//*/
		} else {
			if (info.__subMap === undefined) {
				/**__DEBUG/
				effectTag = 'CmdOnlyEffectModule';
				//*/

				/**__PROD/
				effectTag = 1;
				//*/
			} else {
				/**__DEBUG/
				effectTag = 'CmdAndSubEffectModule';
				//*/

				/**__PROD/
				effectTag = 2;
				//*/
			}
		}

		const elmRecord = {
			__$portSetup: info.__portSetup,
			__$onSelfMsg: info.__onSelfMsg,
			__$init: info.__init,
			__$effects: {
				$: effectTag,
				a: {
					__$onEffects: info.__onEffects,
					__$cmdMap: info.__cmdMap,
					__$subMap: info.__subMap
				}
			}
		};


		initial = func(
			key,
			elmRecord,
			initial
		);
	}
	return initial;
});


function _Platform_setupEffects(sendToApp)
{
	var ports;
	let managers

	// setup all necessary effect managers
	for (var key in _Platform_effectManagers)
	{
		var manager = _Platform_effectManagers[key];

		if (manager.__portSetup)
		{
			ports = ports || {};
			ports[key] = manager.__portSetup(key, sendToApp);
		}

		managers[key] = _Platform_instantiateManager(manager, sendToApp);
	}

	return ports;
}


function _Platform_createManager(init, onEffects, onSelfMsg, cmdMap, subMap)
{
	return {
		__init: init,
		__onEffects: onEffects,
		__onSelfMsg: onSelfMsg,
		__cmdMap: cmdMap,
		__subMap: subMap
	};
}


function _Platform_instantiateManager(info, sendToApp)
{
	var router = {
		__sendToApp: sendToApp,
		__selfProcess: undefined
	};

	var onEffects = info.__onEffects;
	var onSelfMsg = info.__onSelfMsg;
	var cmdMap = info.__cmdMap;
	var subMap = info.__subMap;

	function loop(state)
	{
		return A2(__Scheduler_andThen, loop, __Scheduler_receive(function(msg)
		{
			var value = msg.a;

			/**__DEBUG/
			if (msg.$ === 'Self')
			//*/

			/**__PROD/
			if (msg.$ === 3)
			//*/
			{
				return A3(onSelfMsg, router, value, state);
			}

			return cmdMap && subMap
				? A4(onEffects, router, value.__cmds, value.__subs, state)
				: A3(onEffects, router, cmdMap ? value.__cmds : value.__subs, state);
		}));
	}

	return router.__selfProcess = __Scheduler_rawSpawn(A2(__Scheduler_andThen, loop, info.__init));
}



// ROUTING


var _Platform_sendToApp = F2(function(router, msg)
{
	return __Scheduler_binding(function(callback)
	{
		router.__sendToApp(msg);
		callback(__Scheduler_succeed(__Utils_Tuple0));
	}, false);
});


var _Platform_sendToSelf = F2(function(router, msg)
{
	return A2(__Scheduler_send, router.__selfProcess, {
		/**__DEBUG/
		$: 'Value',
		a: {
			$: 'Self',
			a: msg
		}
		//*/

		/**__PROD/
		$: 3,
		a: msg
		//*/
	});
});



// BAGS


// Called by compiler generated js for event managers
function _Platform_leaf(home)
{
	return function(value)
	{
		/**__DEBUG/
		return {
			$: 'Value',
			a: {
				$: 'Leaf',
				__home: home,
				__value: value
			}
		};
		//*/

		/**__PROD/
		return {
			$: 0,
			__home: home,
			__value: value
		};
		//*/
	};
}


// PIPE BAGS INTO EFFECT MANAGERS


function _Platform_dispatchEffects(managers, cmdBag, subBag)
{
	var effectsDict = {};
	_Platform_gatherEffects(true, _Platform__unwrap_bag(cmdBag), effectsDict, null);
	_Platform_gatherEffects(false, _Platform__unwrap_bag(subBag), effectsDict, null);

	for (var home in managers)
	{
		__Scheduler_rawSend(managers[home], {
			$: 'fx',
			a: effectsDict[home] || { __cmds: __List_Nil, __subs: __List_Nil }
		});
	}
}

function _Platform__unwrap_bag(cmdOrSub)
{
	/**__DEBUG/
	return cmdOrSub.a;
	//*/

	/**__PROD/
	return cmdOrSub;
	//*/
}

function _Platform_gatherEffects(isCmd, bag, effectsDict, taggers)
{
	/**__DEBUG/
	const LEAF = 'Leaf';
	const BATCH = 'Batch';
	const MAP = 'Map';
	//*/

	/**__PROD/
	const LEAF = 0;
	const BATCH = 1;
	const MAP = 2;
	//*/
	switch (bag.$)
	{
		case LEAF:
			var home = bag.__home;
			var effect = _Platform_toEffect(isCmd, home, taggers, bag.__value);
			effectsDict[home] = _Platform_insert(isCmd, effect, effectsDict[home]);
			return;

		case BATCH:
			for (let list = bag.a; list.b; list = list.b) // WHILE_CONS
			{
				_Platform_gatherEffects(isCmd, list.a, effectsDict, taggers);
			}
			return;

		case MAP:
			_Platform_gatherEffects(isCmd, bag.b, effectsDict, {
				__tagger: bag.a,
				__rest: taggers
			});
			return;
	}
}


function _Platform_toEffect(isCmd, home, taggers, value)
{
	function applyTaggers(x)
	{
		for (var temp = taggers; temp; temp = temp.__rest)
		{
			x = temp.__tagger(x);
		}
		return x;
	}

	var map = isCmd
		? _Platform_effectManagers[home].__cmdMap
		: _Platform_effectManagers[home].__subMap;

	return A2(map, applyTaggers, value)
}


function _Platform_insert(isCmd, newEffect, effects)
{
	effects = effects || { __cmds: __List_Nil, __subs: __List_Nil };

	isCmd
		? (effects.__cmds = __List_Cons(newEffect, effects.__cmds))
		: (effects.__subs = __List_Cons(newEffect, effects.__subs));

	return effects;
}



// PORTS


function _Platform_checkPortName(name)
{
	if (_Platform_effectManagers[name])
	{
		__Debug_crash(3, name)
	}
}



// OUTGOING PORTS


function _Platform_outgoingPort(name, converter)
{
	_Platform_checkPortName(name);
	_Platform_effectManagers[name] = {
		__cmdMap: _Platform_outgoingPortMap,
		__converter: converter,
		__portSetup: _Platform_setupOutgoingPort
	};
	return _Platform_leaf(name);
}


var _Platform_outgoingPortMap = F2(function(tagger, value) { return value; });


function _Platform_setupOutgoingPort(name)
{
	var subs = [];
	var converter = _Platform_effectManagers[name].__converter;

	// CREATE MANAGER

	var init = __Process_sleep(0);

	_Platform_effectManagers[name].__init = init;
	_Platform_effectManagers[name].__onEffects = F3(function(router, cmdList, state)
	{
		for ( ; cmdList.b; cmdList = cmdList.b) // WHILE_CONS
		{
			// grab a separate reference to subs in case unsubscribe is called
			var currentSubs = subs;
			var value = __Json_unwrap(converter(cmdList.a));
			for (var i = 0; i < currentSubs.length; i++)
			{
				currentSubs[i](value);
			}
		}
		return init;
	});

	// PUBLIC API

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

	return {
		subscribe: subscribe,
		unsubscribe: unsubscribe
	};
}



// INCOMING PORTS


function _Platform_incomingPort(name, converter)
{
	_Platform_checkPortName(name);
	_Platform_effectManagers[name] = {
		__subMap: _Platform_incomingPortMap,
		__converter: converter,
		__portSetup: _Platform_setupIncomingPort
	};
	return _Platform_leaf(name);
}


var _Platform_incomingPortMap = F2(function(tagger, finalTagger)
{
	return function(value)
	{
		return tagger(finalTagger(value));
	};
});


function _Platform_setupIncomingPort(name, sendToApp)
{
	var subs = __List_Nil;
	var converter = _Platform_effectManagers[name].__converter;

	// CREATE MANAGER

	var init = __Scheduler_succeed(null);

	_Platform_effectManagers[name].__init = init;
	_Platform_effectManagers[name].__onEffects = F3(function(router, subList, state)
	{
		subs = subList;
		return init;
	});

	// PUBLIC API

	function send(incomingValue)
	{
		var result = A2(__Json_run, converter, __Json_wrap(incomingValue));

		__Result_isOk(result) || __Debug_crash(4, name, result.a);

		var value = result.a;
		for (var temp = subs; temp.b; temp = temp.b) // WHILE_CONS
		{
			sendToApp(temp.a(value));
		}
	}

	return { send: send };
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
