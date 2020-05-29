/*

import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Json exposing (run, wrap, unwrap)
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

/* global scope */

// State

const _Platform_ports = {};

const _Platform_runAfterLoadQueue = [];

// TODO(harry) could onSubUpdateFunctions be a WeakMap?
const _Platform_onSubUpdateFunctions = new WeakMap();
let _Platform_guidIdCount = 0;

// INITIALIZE A PROGRAM

const _Platform_initialize = F2((args, mainLoop) => {
  const messageChannel = __Channel_rawUnbounded();

  const sendToApp = (message, viewMetadata) => {
    A2(__Channel_rawSend, messageChannel, __Utils_Tuple2(message, viewMetadata));
  };

  const runtimeId = {
    __$id: _Platform_guidIdCount++,
    __sendToApp: sendToApp,
    __outgoingPortSubs: [],
    __subscriptionStates: new Map(),
  };

  for (const f of _Platform_runAfterLoadQueue) {
    f(runtimeId);
  }

  _Platform_runAfterLoadQueue.loaded = true;

  __RawScheduler_rawSpawn(
    mainLoop({
      __$receiver: messageChannel,
      __$encodedFlags: __Json_wrap(args ? args.flags : undefined),
      __$runtime: runtimeId,
    })
  );

  const ports = {};

  for (const [name, p] of Object.entries(_Platform_ports)) {
    ports[name] = p(runtimeId);
  }

  return { ports };
});

function _Platform_browserifiedSendToApp(runtimeId) {
  return (message, updateMetadata) =>
    runtimeId.__sendToApp(message, updateMetadata ? __Platform_SyncUpdate : __Platform_AsyncUpdate);
}

// EFFECT MANAGERS (not supported)

function _Platform_createManager() {
  __Debug_crash(12, __Debug_runtimeCrashReason("EffectModule"));
}

const _Platform_leaf = (home) => () => {
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
      __Scheduler_execImpure(() => {
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
  const key = { __$id: _Platform_guidIdCount++ };
  const group = { __$id: _Platform_guidIdCount++ };

  const subId = {
    __$key: key,
    __$group: group,
  };
  _Platform_onSubUpdateFunctions.set(group, () => {});

  _Platform_runAfterLoad((runtimeId) => {
    const channel = __Channel_rawUnbounded();
    runtimeId.__subscriptionStates.set(key, { __channel: channel, __listenerGroups: new Map() });
    __RawScheduler_rawSpawn(__Platform_initializeHelperFunctions.__$subListenerProcess(channel));
  });

  return subId;
};

const _Platform_subscriptionWithUpdater = (subId) => (updater) => {
  const group = { __$id: _Platform_guidIdCount++ };
  _Platform_onSubUpdateFunctions.set(group, updater);
  return {
    __$key: subId.__$key,
    __$group: group,
  };
};

const _Platform_subscriptionEvent = F3((subId, runtime, message) => {
  const state = runtime.__subscriptionStates.get(subId.__$key);
  A2(
    __Channel_rawSend,
    state.__channel,
    __RawTask_execImpure(() => {
      for (const listeners of state.__listenerGroups.values()) {
        for (const listener of listeners) {
          __RawScheduler_rawSpawn(listener(message));
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

function _Platform_addListenerToGroup(listenerGroups, group, sendToApp) {
  let listeners = listenerGroups.get(group);
  if (listeners === undefined) {
    listeners = [];
    listenerGroups.set(group, listeners);
  }

  listeners.push(sendToApp);
}

const _Platform_resetSubscriptions = (runtime) => (newSubs) => {
  for (const state of runtime.__subscriptionStates.values()) {
    for (const listeners of state.__listenerGroups.values()) {
      listeners.length = 0;
    }
  }

  for (const tuple of __List_toArray(newSubs)) {
    const subId = tuple.a;
    const sendToApp = tuple.b;
    const listenerGroups = runtime.__subscriptionStates.get(subId.__$key).__listenerGroups;
    _Platform_addListenerToGroup(listenerGroups, subId.__$group, sendToApp);
  }

  // Deletion from a Map whilst iterating is valid:
  // https://stackoverflow.com/questions/35940216/es6-is-it-dangerous-to-delete-elements-from-set-map-during-set-map-iteration
  for (const state of runtime.__subscriptionStates.values()) {
    for (const [groupId, listeners] of state.__listenerGroups.entries()) {
      _Platform_onSubUpdateFunctions.get(groupId)(runtime, listeners.length);
      if (listeners.length === 0) {
        state.__listenerGroups.delete(groupId);
      }
    }
  }

  return __Utils_Tuple0;
};

function _Platform_invalidFlags(stringifiedError) {
  if (__Basics_isDebug) {
    __Debug_crash(2, stringifiedError);
  } else {
    __Debug_crash(2);
  }
}

const _Platform_sendToApp = (runtimeId) => (message) => (viewMetadata) =>
  __RawTask_execImpure(() => runtimeId.__sendToApp(message, viewMetadata));

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
    _Platform_mergeExports("Elm", scope.Elm, exports);
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

/* ESLINT GLOBAL VARIABLES"
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py.
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Platform_.*" }] */

/* global __Debug_crash, __Debug_runtimeCrashReason */
/* global __Json_run, __Json_wrap, __Json_unwrap */
/* global __List_Cons, __List_Nil, __List_toArray */
/* global __Utils_Tuple0, __Utils_Tuple2 */
/* global __Channel_rawUnbounded, __Channel_rawSend */
/* global __Basics_isDebug */
/* global __Result_isOk */
/* global __Maybe_Nothing */
/* global __Platform_Task, __Platform_ProcessId, __Platform_initializeHelperFunctions, __Platform_AsyncUpdate, __Platform_SyncUpdate */
/* global __RawScheduler_rawSpawn */
/* global __RawTask_execImpure */
/* global __Scheduler_execImpure, __Scheduler_andThen, __Scheduler_map, __Scheduler_binding */
