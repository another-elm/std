/*

import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Json exposing (run, wrap, unwrap)
import Elm.Kernel.List exposing (iterate, fromArray)
import Elm.Kernel.Utils exposing (Tuple0, Tuple2)
import Elm.Kernel.Channel exposing (rawUnbounded, rawSend)
import Elm.Kernel.Basics exposing (isDebug)
import Result exposing (isOk)
import Maybe exposing (Nothing, Just)
import Platform exposing (initializeHelperFunctions, AsyncUpdate, SyncUpdate)
import Platform.Raw.Task as RawTask exposing (execImpure, syncBinding)

*/

/* global scope */

// State

const _Platform_ports = new Map();

const _Platform_runAfterLoadQueue = [];
const _Platform_eventSubscriptionListeners = new WeakMap();

let _Platform_guidIdCount = 0;
let _Platform_initDone = false;

// INITIALIZE A PROGRAM

const _Platform_initialize = F2((args, mainLoop) => {
  _Platform_initDone = true;
  const messageChannel = __Channel_rawUnbounded();

  const runtimeId = {
    __$id: _Platform_guidIdCount++,
    __messageChannel: messageChannel,
    __outgoingPortSubs: new Map(),
    __incomingPortSubManagers: new Map(),
    __eventSubscriptionListeners: new Map(),
    __runtimeSubscriptionHandlers: new Map(),
  };

  for (const f of _Platform_runAfterLoadQueue) {
    f(runtimeId);
  }

  mainLoop({
    __$receiver: messageChannel,
    __$encodedFlags: __Json_wrap(args ? args.flags : undefined),
    __$runtime: runtimeId,
  });

  const ports = {};

  for (const [name, p] of _Platform_ports.entries()) {
    ports[name] = p(runtimeId);
  }

  return { ports };
});

const _Platform_browserifiedSendToApp = (runtimeId) => (message, updateMetadata) => {
  const meta = updateMetadata ? __Platform_SyncUpdate : __Platform_AsyncUpdate;
  return __Channel_rawSend(runtimeId.__messageChannel)(__Utils_Tuple2(message, meta));
};

// EFFECT MANAGERS (not supported)

function _Platform_createManager() {
  __Debug_crash(12, __Debug_runtimeCrashReason("EffectModule"));
}

const _Platform_leaf = (home) => () => {
  __Debug_crash(12, __Debug_runtimeCrashReason("PlatformLeaf", home));
};

// PORTS

function _Platform_registerPort(name, portInit) {
  if (_Platform_ports.has(name)) {
    __Debug_crash(3, name);
  }

  _Platform_ports.set(name, portInit);
}

function _Platform_outgoingPort(name, converter) {
  _Platform_registerPort(name, (runtimeId) => {
    const subscribe = (callback) => {
      _Platform_mapGetOrInit(runtimeId.__outgoingPortSubs, name, () => []).push(callback);
    };

    const unsubscribe = (callback) => {
      let subs = runtimeId.__outgoingPortSubs.get();
      if (subs === undefined) {
        return;
      }

      subs = subs.filter((sub) => sub !== callback);
      if (subs.length === 0) {
        runtimeId.__outgoingPortSubs.delete(name);
      } else {
        runtimeId.__outgoingPortSubs.set(name, subs);
      }
    };

    return { subscribe, unsubscribe };
  });

  return (payload) =>
    _Platform_command((runtimeId) =>
      __RawTask_execImpure(() => {
        const value = __Json_unwrap(converter(payload));
        const subs = runtimeId.__outgoingPortSubs.get(name);
        if (subs !== undefined) {
          for (const sub of subs) {
            sub(value);
          }
        }

        return __Maybe_Nothing;
      })
    );
}

function _Platform_incomingPort(name, converter) {
  const managerId = _Platform_registerRuntimeSubscriptionHandler(__Utils_Tuple0);

  _Platform_registerPort(name, (runtimeId) => {
    function send(incomingValue) {
      const result = A2(__Json_run, converter, __Json_wrap(incomingValue));

      if (!__Result_isOk(result)) {
        __Debug_crash(4, name, result.a);
      }

      _Platform_handleMessageForRuntime(runtimeId, managerId, __Utils_Tuple0, result.a);
    }

    return { send };
  });

  const makeSub = __Basics_isDebug
    ? (a) => ({
        $: "Sub",
        a,
      })
    : (a) => a;

  return (tagger) =>
    makeSub(
      makeSub(
        __List_fromArray([
          {
            __$managerId: managerId,
            __$subId: __Utils_Tuple0,
            __$onMessage: (x) => __Maybe_Just(tagger(x)),
          },
        ])
      )
    );
}

// FUNCTIONS (to be used by kernel code)

const _Platform_createSubscriptionGroup = (updater) => ({
  __$id: _Platform_guidIdCount++,
  __$runtimesListening: new Set(),
  __$updater: updater,
});

const _Platform_runAfterLoad = (f) => {
  _Platform_assertNotLoaded();
  _Platform_runAfterLoadQueue.push(f);
};

const _Platform_assertNotLoaded = () => {
  if (_Platform_initDone) {
    __Debug_crash(12, __Debug_runtimeCrashReason("alreadyLoaded"));
  }
};

// FUNCTIONS (to be used by elm code)

const _Platform_registerEventSubscriptionListener = (onSubEffects) => {
  _Platform_assertNotLoaded();
  const subManagerId = {
    __$id: _Platform_guidIdCount++,
  };
  _Platform_eventSubscriptionListeners.set(subManagerId, onSubEffects);
  return subManagerId;
};

// TODO(harry): what is this param?
const _Platform_registerRuntimeSubscriptionHandler = () => {
  _Platform_assertNotLoaded();
  const subManagerId = {
    __$id: _Platform_guidIdCount++,
  };
  return subManagerId;
};

function _Platform_mapGetOrInit(map, key, func) {
  let value = map.get(key);
  if (value === undefined) {
    value = func();
    map.set(key, value);
  }

  return value;
}

const _Platform_resetSubscriptions = (runtime) => (newSubs) => {
  const eventSubscriptionListeners = runtime.__eventSubscriptionListeners;
  for (const [, managerState] of eventSubscriptionListeners.entries()) {
    for (const subData of managerState.values()) {
      subData.__taggers.length = 0;
    }
  }

  for (const taggers of runtime.__runtimeSubscriptionHandlers.values()) {
    taggers.length = 0;
  }

  for (const newSub of __List_iterate(newSubs)) {
    const eventListener = _Platform_eventSubscriptionListeners.get(newSub.__$managerId);
    if (eventListener === undefined) {
      // We have a subscription managed by a runtime handler.
      const taggers = _Platform_mapGetOrInit(
        runtime.__runtimeSubscriptionHandlers,
        newSub.__$managerId,
        () => []
      );
      taggers.push((subId) => (payload) => {
        if (subId === newSub.__$subId) {
          return newSub.__$onMessage(payload);
        }
      });
    } else {
      const managerState = _Platform_mapGetOrInit(
        eventSubscriptionListeners,
        newSub.__$managerId,
        () => new Map()
      );
      const effect = _Platform_mapGetOrInit(managerState, newSub.__$subId, () => {
        const taggers = [];
        const effectId = eventListener.__$new(newSub.__$effectData)((payload) => {
          for (const tagger of taggers) {
            const mMessage = tagger(payload);
            if (mMessage !== __Maybe_Nothing) {
              _Platform_sendToApp(runtime)(__Utils_Tuple2(mMessage.a, __Platform_AsyncUpdate));
            }
          }
        });
        return {
          __taggers: taggers,
          __effectId: effectId,
          __discontinued: eventListener.__$discontinued,
        };
      });
      effect.__taggers.push(newSub.__$onMessage);
    }
  }

  for (const [, managerState] of eventSubscriptionListeners.entries()) {
    for (const [subId, subData] of managerState.entries()) {
      if (subData.__taggers.length === 0) {
        subData.__discontinued(subData.__effectId);
        // Deletion from a Map whilst iterating is valid:
        // https://stackoverflow.com/questions/35940216/es6-is-it-dangerous-to-delete-elements-from-set-map-during-set-map-iteration
        managerState.delete(subId);
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

const _Platform_sendToApp = (runtimeId) => __Channel_rawSend(runtimeId.__messageChannel);

const _Platform_handleMessageForRuntime = (runtimeId, managerId, subId, value) => {
  const taggers = runtimeId.__runtimeSubscriptionHandlers.get(managerId);

  if (taggers !== undefined) {
    for (const tagger of taggers) {
      const mMessage = tagger(subId)(value);
      if (mMessage !== __Maybe_Nothing) {
        _Platform_sendToApp(runtimeId)(__Utils_Tuple2(mMessage.a, __Platform_AsyncUpdate));
      }
    }
  }
};

// command : (RuntimeId -> Platform.Task Never (Maybe msg)) -> Cmd msg
const _Platform_command = (createTask) => {
  return __Platform_initializeHelperFunctions.__$createCmd(createTask);
};

// valueStore :
//     Platform.Task Never state
//     -> Impure.Function (state -> Platform.Task Never ( x, state )) (Platform.Task never a)
const _Platform_valueStore = (init) => {
  let task = init;
  return (stepper) =>
    __RawTask_syncBinding(() => {
      const tuple = A2(__Platform_initializeHelperFunctions.__$valueStoreHelper, task, stepper);
      task = tuple.b;
      return tuple.a;
    });
};

function _Platform_randSeed() {
  return typeof scope !== "undefined" && Object.prototype.hasOwnProperty.call(scope, `_randSeed`)
    ? scope._randSeed()
    : Math.floor(Math.random() * 2 ** 32);
}

// EXPORT ELM MODULES

function _Platform_export(exports) {
  scope._another_elm = "ANOTHER-ELM-VERSION";
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

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Platform_.*" }] */

/* global __Debug_crash, __Debug_runtimeCrashReason */
/* global __Json_run, __Json_wrap, __Json_unwrap */
/* global __List_iterate, __List_fromArray */
/* global __Utils_Tuple0, __Utils_Tuple2 */
/* global __Channel_rawUnbounded, __Channel_rawSend */
/* global __Basics_isDebug */
/* global __Result_isOk */
/* global __Maybe_Nothing, __Maybe_Just */
/* global __Platform_initializeHelperFunctions, __Platform_AsyncUpdate, __Platform_SyncUpdate */
/* global __RawTask_execImpure, __RawTask_syncBinding */
