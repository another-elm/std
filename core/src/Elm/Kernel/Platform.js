/*

import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Json exposing (run, wrap, unwrap, errorToString)
import Elm.Kernel.List exposing (Cons, Nil, toArray)
import Elm.Kernel.Utils exposing (Tuple0, Tuple2)
import Elm.Kernel.Channel exposing (rawUnbounded, rawSend)
import Elm.Kernel.Basics exposing (isDebug)
import Result exposing (isOk)
import Maybe exposing (Nothing)
import Platform exposing (Task, ProcessId, initializeHelperFunctions, AsyncUpdate, SyncUpdate)
import Platform.Raw.Scheduler as RawScheduler exposing (rawSpawn)
import Platform.Raw.Task as RawTask exposing (execImpure)
import Platform.Scheduler as Scheduler exposing (execImpure, andThen, map, binding)

*/

// State

const _Platform_ports = {};

const _Platform_effectsQueue = [];
let _Platform_effectDispatchInProgress = false;

const _Platform_runAfterLoadQueue = [];

const _Platform_onSubUpdateFunctions = new Map();
const _Platform_runtimeCount = 0;

// INITIALIZE A PROGRAM

const _Platform_initialize = F4((flagDecoder, args, impl, stepperBuilder) => {
  // Elm.Kernel.Json.wrap : RawJsObject -> Json.Decode.Value
  // Elm.Kernel.Json.run : Json.Decode.Decoder a -> Json.Decode.Value -> Result Json.Decode.Error a
  const flagsResult = A2(__Json_run, flagDecoder, __Json_wrap(args ? args.flags : undefined));

  if (!__Result_isOk(flagsResult)) {
    if (__Basics_isDebug) {
      __Debug_crash(2, __Json_errorToString(result.a));
    } else {
      __Debug_crash(2);
    }
  }

  const sendToApp = F2((message, viewMetadata) => {
    const updateValue = A2(impl.__$update, message, model);
    model = updateValue.a;
    A2(stepper, model, viewMetadata);
    dispatch(model, updateValue.b);
  });

  const runtimeId = {
    __$id: _Platform_runtimeCount,
    __sendToApp: sendToApp,
    __outgoingPortSubs: [],
    __subscriptionListeners: new Map(),
    __subscriptionChannels: new Map(),
  };

  const cmdChannel = __Channel_rawUnbounded();

  const dispatch = (model, cmds) => {
    _Platform_effectsQueue.push({
      __cmds: cmds,
      __subs: impl.__$subscriptions(model),
    });

    if (_Platform_effectDispatchInProgress) {
      return;
    }

    _Platform_effectDispatchInProgress = true;
    for (;;) {
      const fx = _Platform_effectsQueue.shift();
      if (fx === undefined) {
        _Platform_effectDispatchInProgress = false;
        return;
      }

      A2(__Channel_rawSend, cmdChannel, fx.__cmds);
      __Platform_initializeHelperFunctions.__$updateSubListeners(fx.__subs)(runtimeId);
    }
  };

  for (const f of _Platform_runAfterLoadQueue) {
    f(runtimeId);
  }

  _Platform_runAfterLoadQueue.loaded = true;

  __RawScheduler_rawSpawn(
    A2(__Platform_initializeHelperFunctions.__$setupEffectsChannel, runtimeId, cmdChannel)
  );

  const initValue = impl.__$init(flagsResult.a);
  let model = initValue.a;
  const stepper = A2(stepperBuilder, sendToApp, model);

  dispatch(model, initValue.b);

  const ports = {};

  for (const [name, p] of Object.entries(_Platform_ports)) {
    ports[name] = p(runtimeId);
  }

  return { ports };
});

function _Platform_browserifiedSendToApp(sendToApp) {
  return (message, updateMetadata) =>
    sendToApp(message)(
      updateMetadata === undefined ? __Platform_AsyncUpdate : __Platform_SyncUpdate
    );
}

// EFFECT MANAGERS (not supported)

function _Platform_createManager(init, onEffects, onSelfMessage, cmdMap, subMap) {
  __Debug_crash(12, __Debug_runtimeCrashReason("EffectModule"));
}

const _Platform_leaf = (home) => (value) => {
  __Debug_crash(12, __Debug_runtimeCrashReason("PlatformLeaf", home));
};

// PORTS

function _Platform_checkPortName(name) {
  if (Object.prototype.hasOwnProperty.call(_Platform_ports, name)) {
    __Debug_crash(3, name);
  }
}

function _Platform_outgoingPort(name, converter) {
  _Platform_checkPortName(name);

  _Platform_ports[name] = (runtimeId) => {
    const subscribe = (callback) => {
      runtimeId.__outgoingPortSubs.push(callback);
    };

    const unsubscribe = (callback) => {
      runtimeId.__outgoingPortSubs = runtimeId.__outgoingPortSubs.filter((sub) => sub !== callback);
    };

    return { subscribe, unsubscribe };
  };

  return (payload) =>
    _Platform_command((runtimeId) =>
      __Scheduler_execImpure((_) => {
        const value = __Json_unwrap(converter(payload));
        for (const sub of runtimeId.__outgoingPortSubs) {
          sub(value);
        }

        return __Maybe_Nothing;
      })
    );
}

function _Platform_incomingPort(name, converter) {
  _Platform_checkPortName(name);
  const subId = _Platform_createSubscriptionId();

  _Platform_ports[name] = (runtimeId) => {
    function send(incomingValue) {
      const result = A2(__Json_run, converter, __Json_wrap(incomingValue));

      if (!__Result_isOk(result)) {
        __Debug_crash(4, name, result.a);
      }

      const value = result.a;
      A3(_Platform_subscriptionEvent, subId, runtimeId, value);
    }

    return { send };
  };

  return _Platform_subscription(subId);
}

// FUNCTIONS (to be used by kernel code)

/**
 * Create a new subscription id. Such ids can be used with the subscription
 * function to create `Sub`s.
 */
const _Platform_createSubscriptionId = () => {
  const key = Symbol("subscription key");
  const group = Symbol("default subscription group");

  const subId = {
    __$key: key,
    __$group: group,
  };
  _Platform_onSubUpdateFunctions.set(group, (_runtimeId, _listenerCount) => {});

  _Platform_runAfterLoad((runtimeId) => {
    const channel = __Channel_rawUnbounded();
    runtimeId.__subscriptionChannels.set(key, channel);
    __RawScheduler_rawSpawn(__Platform_initializeHelperFunctions.__$subListenerProcess(channel));
  });

  return subId;
};

const _Platform_subscriptionWithUpdater = (subId) => (updater) => {
  const group = Symbol("new subscription group");
  _Platform_onSubUpdateFunctions.set(group, updater);
  return {
    __$key: subId.__$key,
    __$group: group,
  };
};

const _Platform_subscriptionEvent = F3((subId, runtime, message) => {
  A2(
    __Channel_rawSend,
    runtime.__subscriptionChannels.get(subId.__$key),
    __RawTask_execImpure((_) => {
      // TODO(harry) sendToApp via spawning a Task
      const listenerGroup = runtime.__subscriptionListeners.get(subId.__$key);
      for (const listeners of listenerGroup.values()) {
        for (const listener of listeners) {
          listener(message);
        }
      }

      return __Utils_Tuple0;
    })
  );
});

const _Platform_runAfterLoad = (f) => {
  if (_Platform_runAfterLoadQueue.loaded) {
    __Debug_crash(12, __Debug_runtimeCrashReason("alreadyLoaded"));
  } else {
    _Platform_runAfterLoadQueue.push(f);
  }
};

// FUNCTIONS (to be used by elm code)

function _Platform_get_or_set(map, key, f) {
  let value = map.get(key);
  if (value === undefined) {
    value = f();
    map.set(key, value);
  }

  return value;
}

const _Platform_resetSubscriptions = (runtime) => (newSubs) => {
  for (const listenerGroup of runtime.__subscriptionListeners.values()) {
    for (const listeners of listenerGroup.values()) {
      listeners.length = 0;
    }
  }

  for (const tuple of __List_toArray(newSubs)) {
    const subId = tuple.a;
    const sendToApp = tuple.b;
    const listenerGroup = _Platform_get_or_set(
      runtime.__subscriptionListeners,
      subId.__$key,
      () => new Map()
    );
    const listeners = _Platform_get_or_set(listenerGroup, subId, () => []);
    listeners.push(sendToApp);
  }

  // Deletion from a Map whilst iterating is valid:
  // https://stackoverflow.com/questions/35940216/es6-is-it-dangerous-to-delete-elements-from-set-map-during-set-map-iteration
  for (const [key, listenerGroup] of runtime.__subscriptionListeners.entries()) {
    for (const [subId, listeners] of listenerGroup.entries()) {
      _Platform_onSubUpdateFunctions.get(subId.__$group)(runtime, listeners.length);
      if (listeners.length === 0) {
        listenerGroup.delete(subId);
      }
    }

    if (listenerGroup.size === 0) {
      runtime.__subscriptionListeners.delete(key);
    }
  }

  return __Utils_Tuple0;
};

const _Platform_sendToAppFunction = (runtimeId) => runtimeId.__sendToApp;

const _Platform_wrapTask = (task) => __Platform_Task(task);

const _Platform_wrapProcessId = (processId) => __Platform_ProcessId(processId);

// command : (RuntimeId -> Platform.Task Never (Maybe msg)) -> Cmd msg
const _Platform_command = (createTask) => {
  const cmdData = __List_Cons(createTask, __List_Nil);
  if (__Basics_isDebug) {
    return {
      $: "Cmd",
      a: cmdData,
    };
  }

  return cmdData;
};

// subscription : RawSub.Id -> (Effect.HiddenConvertedSubType -> msg) -> Sub msg
const _Platform_subscription = (key) => (tagger) => {
  const subData = __List_Cons(__Utils_Tuple2(key, tagger), __List_Nil);
  if (__Basics_isDebug) {
    return {
      $: "Sub",
      a: subData,
    };
  }

  return subData;
};

// valueStore :
//     Platform.Task Never state
//     -> (state -> Platform.Task Never ( x, state ))
//     -> Platform never x
const _Platform_valueStore = (init) => {
  let task = init;
  return (stepper) =>
    __Scheduler_binding({
      __$then_: (callback) => () => {
        const newTask = A2(__Scheduler_andThen, stepper, task);
        task = A2(__Scheduler_map, (tuple) => tuple.b, newTask);
        callback(A2(__Scheduler_map, (tuple) => tuple.a, newTask))();
        return (x) => x;
      },
    });
};

// EXPORT ELM MODULES
//
// Have DEBUG and PROD versions so that we can (1) give nicer errors in debug
// mode and (2) not pay for the bits needed for that in prod mode.
//

function _Platform_export(exports) {
  if (Object.prototype.hasOwnProperty.call(scope, "Elm")) {
    _Platform_mergeExportsProd("Elm", scope.Elm, exports);
  } else {
    scope.Elm = exports;
  }
}

function _Platform_mergeExports(moduleName, object, exports) {
  for (const name of Object.keys(exports)) {
    if (Object.prototype.hasOwnProperty.call(object, name)) {
      if (name === "init") {
        __Debug_crash(6, moduleName);
      } else {
        _Platform_mergeExports(moduleName + "." + name, object[name], exports[name]);
      }
    } else {
      object[name] = exports[name];
    }
  }
}
