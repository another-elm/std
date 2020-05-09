/*

import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Json exposing (run, wrap, unwrap, errorToString)
import Elm.Kernel.List exposing (Cons, Nil, toArray)
import Elm.Kernel.Utils exposing (Tuple0, Tuple2)
import Elm.Kernel.Channel exposing (rawUnbounded, rawSend)
import Elm.Kernel.Basics exposing (isDebug)
import Result exposing (isOk)
import Maybe exposing (Nothing)
import Platform exposing (Task, ProcessId, initializeHelperFunctions)
import Platform.Raw.Scheduler as RawScheduler exposing (rawSpawn)
import Platform.Raw.Task as RawTask exposing (execImpure, andThen)
import Platform.Raw.Channel as RawChannel exposing (recv)
import Platform.Scheduler as Scheduler exposing (execImpure, andThen, map, binding)

*/

// State

var _Platform_outgoingPorts = new Map();
var _Platform_incomingPorts = new Map();

var _Platform_effectsQueue = [];
var _Platform_effectDispatchInProgress = false;

let _Platform_runAfterLoadQueue = [];
const _Platform_runAfterLoad = (f) => {
  if (_Platform_runAfterLoadQueue == null) {
    f();
  } else {
    _Platform_runAfterLoadQueue.push(f);
  }
};

// INITIALIZE A PROGRAM

const _Platform_initialize = F3((flagDecoder, args, impl) => {
  // Elm.Kernel.Json.wrap : RawJsObject -> Json.Decode.Value
  // Elm.Kernel.Json.run : Json.Decode.Decoder a -> Json.Decode.Value -> Result Json.Decode.Error a
  const flagsResult = A2(__Json_run, flagDecoder, __Json_wrap(args ? args["flags"] : undefined));

  if (!__Result_isOk(flagsResult)) {
    if (__Basics_isDebug) {
      __Debug_crash(2, __Json_errorToString(result.a));
    } else {
      __Debug_crash(2);
    }
  }

  let cmdSender;
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
      const tuple = A3(
        __Platform_initializeHelperFunctions.__$dispatchEffects,
        fx.__cmds,
        fx.__subs,
        cmdSender
      );
      tuple.a(sendToApp);
      __RawScheduler_rawSpawn(tuple.b);
    }
  };

  const sendToApp = F2((msg, viewMetadata) => {
    const updateValue = A2(impl.__$update, msg, model);
    model = updateValue.a;
    A2(stepper, model, viewMetadata);
    dispatch(model, updateValue.b);
  });

  for (const f of _Platform_runAfterLoadQueue) {
    f();
  }
  _Platform_runAfterLoadQueue = null;

  cmdSender = __Platform_initializeHelperFunctions.__$setupEffectsChannel(sendToApp);

  for (const [key, { port }] of _Platform_outgoingPorts.entries()) {
    ports[key] = port;
  }
  for (const [key, { port }] of _Platform_incomingPorts.entries()) {
    ports[key] = port;
  }

  const initValue = impl.__$init(flagsResult.a);
  let model = initValue.a;
  const stepper = A2(__Platform_initializeHelperFunctions.__$stepperBuilder, sendToApp, model);

  dispatch(model, initValue.b);

  return ports ? { ports } : {};
});

// TRACK PRELOADS
//
// This is used by code in elm/browser and elm/http
// to register any HTTP requests that are triggered by init.
//

var _Platform_preload;

function _Platform_registerPreload(url) {
  _Platform_preload.add(url);
}

// EFFECT MANAGERS

function _Platform_createManager(init, onEffects, onSelfMsg, cmdMap, subMap) {
  __Debug_crash(12, __Debug_runtimeCrashReason("EffectModule"));
}

// BAGS

/* Called by compiler generated js for event managers for the
 * `command` or `subscription` function within an event manager
 */
const _Platform_leaf = (home) => (value) => {
  __Debug_crash(12, __Debug_runtimeCrashReason("PlatformLeaf", home));
};

// PORTS

function _Platform_checkPortName(name) {
  if (_Platform_outgoingPorts.has(name) || _Platform_incomingPorts.has(name)) {
    __Debug_crash(3, name);
  }
}

function _Platform_outgoingPort(name, converter) {
  _Platform_checkPortName(name);
  let subs = [];
  const subscribe = (callback) => {
    subs.push(callback);
  };
  const unsubscribe = (callback) => {
    // copy subs into a new array in case unsubscribe is called within
    // a subscribed callback
    subs = subs.slice();
    var index = subs.indexOf(callback);
    if (index >= 0) {
      subs.splice(index, 1);
    }
  };
  const execSubscribers = (payload) => {
    const value = __Json_unwrap(converter(payload));
    for (const sub of subs) {
      sub(value);
    }
    return __Utils_Tuple0;
  };
  _Platform_outgoingPorts.set(name, {
    port: {
      subscribe,
      unsubscribe,
    },
  });

  return (payload) =>
    _Platform_command(
      __Scheduler_execImpure((_) => {
        execSubscribers(payload);
        return __Maybe_Nothing;
      })
    );
}

function _Platform_incomingPort(name, converter) {
  _Platform_checkPortName(name);

  const tuple = _Platform_createSubProcess((_) => __Utils_Tuple0);
  const key = tuple.a;
  const sender = tuple.b;

  function send(incomingValue) {
    var result = A2(__Json_run, converter, __Json_wrap(incomingValue));

    __Result_isOk(result) || __Debug_crash(4, name, result.a);

    var value = result.a;
    A2(__Channel_rawSend, sender, value);
  }

  _Platform_incomingPorts.set(name, {
    port: {
      send,
    },
  });

  return _Platform_subscription(key);
}

// Functions exported to elm

const _Platform_subscriptionStates = new Map();
let _Platform_subscriptionProcessIds = 0;

const _Platform_createSubProcess = (onSubUpdate) => {
  const channel = __Channel_rawUnbounded();
  const key = { id: _Platform_subscriptionProcessIds++ };
  const msgHandler = (hcst) =>
    __RawTask_execImpure((_) => {
      const subscriptionState = _Platform_subscriptionStates.get(key);
      if (__Basics_isDebug && subscriptionState === undefined) {
        __Debug_crash(12, __Debug_runtimeCrashReason("subscriptionProcessMissing"), key && key.id);
      }
      for (const sendToApp of subscriptionState.__$listeners) {
        sendToApp(hcst);
      }
      return __Utils_Tuple0;
    });

  const onSubEffects = (_) =>
    A2(__RawTask_andThen, onSubEffects, A2(__RawChannel_recv, msgHandler, channel.b));

  _Platform_subscriptionStates.set(key, {
    __$listeners: [],
    __$onSubUpdate: onSubUpdate,
  });
  _Platform_runAfterLoad(() => __RawScheduler_rawSpawn(onSubEffects(__Utils_Tuple0)));

  return __Utils_Tuple2(key, channel.a);
};

const _Platform_resetSubscriptions = (newSubs) => {
  for (const subState of _Platform_subscriptionStates.values()) {
    subState.__$listeners.length = 0;
  }
  for (const tuple of __List_toArray(newSubs)) {
    const key = tuple.a;
    const sendToApp = tuple.b;
    const subState = _Platform_subscriptionStates.get(key);
    if (__Basics_isDebug && subState.__$listeners === undefined) {
      __Debug_crash(12, __Debug_runtimeCrashReason("subscriptionProcessMissing"), key && key.id);
    }
    subState.__$listeners.push(sendToApp);
  }
  for (const subState of _Platform_subscriptionStates.values()) {
    subState.__$onSubUpdate(subState.__$listeners.length);
  }
  return __Utils_Tuple0;
};

const _Platform_effectManagerNameToString = (name) => name;

const _Platform_wrapTask = (task) => __Platform_Task(task);

const _Platform_wrapProcessId = (processId) => __Platform_ProcessId(processId);

// command : Platform.Task Never (Maybe msg) -> Cmd msg
const _Platform_command = (task) => {
  const cmdData = __List_Cons(task, __List_Nil);
  if (__Basics_isDebug) {
    return {
      $: "Cmd",
      a: cmdData,
    };
  }
  return cmdData;
};

// subscription : RawSub.Id -> (RawSub.HiddenConvertedSubType -> msg) -> Sub msg
const _Platform_subscription = (id) => (tagger) => {
  const subData = __List_Cons(__Utils_Tuple2(id, tagger), __List_Nil);
  if (__Basics_isDebug) {
    return {
      $: "Sub",
      a: subData,
    };
  }
  return subData;
};

// EXPORT ELM MODULES
//
// Have DEBUG and PROD versions so that we can (1) give nicer errors in
// debug mode and (2) not pay for the bits needed for that in prod mode.
//

function _Platform_export__PROD(exports) {
  scope["Elm"] ? _Platform_mergeExportsProd(scope["Elm"], exports) : (scope["Elm"] = exports);
}

function _Platform_mergeExportsProd(obj, exports) {
  for (var name in exports) {
    name in obj
      ? name == "init"
        ? __Debug_crash(6)
        : _Platform_mergeExportsProd(obj[name], exports[name])
      : (obj[name] = exports[name]);
  }
}

function _Platform_export__DEBUG(exports) {
  scope["Elm"]
    ? _Platform_mergeExportsDebug("Elm", scope["Elm"], exports)
    : (scope["Elm"] = exports);
}

function _Platform_mergeExportsDebug(moduleName, obj, exports) {
  for (var name in exports) {
    name in obj
      ? name == "init"
        ? __Debug_crash(6, moduleName)
        : _Platform_mergeExportsDebug(moduleName + "." + name, obj[name], exports[name])
      : (obj[name] = exports[name]);
  }
}

const _Platform_valueStore = (init) => {
  let task = init;
  return (stepper) =>
    __Scheduler_binding({
      __$then_: (callback) => {
        const newTask = A2(__Scheduler_andThen, stepper, task);
        task = A2(__Scheduler_map, (tuple) => tuple.b, newTask);
        callback(A2(__Scheduler_map, (tuple) => tuple.a, newTask));
        return (x) => x;
      },
    });
};
