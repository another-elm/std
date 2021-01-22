/*

import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Json exposing (run, wrap, unwrap)
import Elm.Kernel.List exposing (iterate, fromArray)
import Elm.Kernel.Utils exposing (Tuple0, Tuple2)
import Elm.Kernel.Channel exposing (rawUnbounded, rawSend)
import Elm.Kernel.Basics exposing (isDebug)
import Result exposing (isOk)
import Maybe exposing (Nothing)
import Platform exposing (initializeHelperFunctions, AsyncUpdate, SyncUpdate)
import Platform.Raw.Task as RawTask exposing (execImpure, syncBinding)

*/

/* global scope */

// State

const _Platform_ports = new Map();

const _Platform_runAfterLoadQueue = [];
const _Platform_eventSubscriptionListeners = new WeakMap();
const _Platform_runtimeSubscriptionHandlers = new WeakMap();

let _Platform_guidIdCount = 0;
let _Platform_initDone = false;

// INITIALIZE A PROGRAM

const _Platform_initialize = F2((args, mainLoop) => {
  _Platform_initDone = true;
  const messageChannel = __Channel_rawUnbounded();

  const runtimeId = {
    __$id: _Platform_guidIdCount++,
    __messageChannel: messageChannel,
    __outgoingPortSubs: [],
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
      runtimeId.__outgoingPortSubs.push(callback);
    };

    const unsubscribe = (callback) => {
      runtimeId.__outgoingPortSubs = runtimeId.__outgoingPortSubs.filter((sub) => sub !== callback);
    };

    return { subscribe, unsubscribe };
  });

  return (payload) =>
    _Platform_command((runtimeId) =>
      __RawTask_execImpure(() => {
        const value = __Json_unwrap(converter(payload));
        for (const sub of runtimeId.__outgoingPortSubs) {
          sub(value);
        }

        return __Maybe_Nothing;
      })
    );
}

function _Platform_incomingPort(name, converter) {
  // Create a dummy (empty) subscription manager. Incoming port subscriptions
  // are fundamentally special because the data gets sent to a _specific
  // runtime_.
  const subscriptionManager = {
    __$new: () => () => __Utils_Tuple0,
    __$continued: () => __Utils_Tuple0,
    __$discontinued: () => __Utils_Tuple0,
  };

  const managerId = _Platform_registerRuntimeSubscriptionHandler(subscriptionManager);

  _Platform_registerPort(name, (runtimeId) => {
    let taggers = runtimeId.__runtimeSubscriptionHandlers.get(managerId);
    if (taggers === undefined) {
      taggers = [];
      runtimeId.__runtimeSubscriptionHandlers.set(managerId, taggers);
    }
    function send(incomingValue) {
      const result = A2(__Json_run, converter, __Json_wrap(incomingValue));

      if (!__Result_isOk(result)) {
        __Debug_crash(4, name, result.a);
      }

      const value = result.a;
      for (const tagger of taggers) {

        _Platform_sendToApp(runtimeId)(
          __Utils_Tuple2(tagger(__Utils_Tuple0)(value), __Platform_AsyncUpdate)
        );
      }
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
            __$onMessage: tagger,
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
const _Platform_registerRuntimeSubscriptionHandler = (onSubEffects) => {
  _Platform_assertNotLoaded();
  const subManagerId = {
    __$id: _Platform_guidIdCount++,
  };
  _Platform_runtimeSubscriptionHandlers.set(subManagerId, onSubEffects);
  return subManagerId;
};

const _Platform_resetSubscriptions = (runtime) => (newSubs) => {
  const eventSubscriptionListeners = runtime.__eventSubscriptionListeners;
  const runtimeSubscriptionHandlers = runtime.__runtimeSubscriptionHandlers;
  for (const [, managerState] of eventSubscriptionListeners.entries()) {
    for (const subData of managerState.values()) {
      subData.__taggers.length = 0;
    }
  }

  for (const taggers of runtimeSubscriptionHandlers.values()) {
    taggers.length = 0;
  }

  for (const newSub of __List_iterate(newSubs)) {
    const eventListener = _Platform_eventSubscriptionListeners.get(newSub.__$managerId);
    if (eventListener === undefined) {
      const runtimeHandler = _Platform_runtimeSubscriptionHandlers.get(newSub.__$managerId);

      if (runtimeHandler === undefined) {
        throw new Error("TODO(harry) add crash");
      }

      // Handle port subscriptions specially
      let taggers = runtimeSubscriptionHandlers.get(newSub.__$managerId);
      if (taggers === undefined) {
        taggers = [];
        runtimeSubscriptionHandlers.set(newSub.__$managerId, taggers);
      }
      taggers.push((subId) => (payload) => {
        if (subId === newSub.__$subId) {
          return newSub.__$onMessage(payload);
        }
      });
    } else {
      let managerState = eventSubscriptionListeners.get(newSub.__$managerId);
      if (managerState === undefined) {
        managerState = new Map();
        eventSubscriptionListeners.set(newSub.__$managerId, managerState);
      }

      const effect = managerState.get(newSub.__$subId);
      if (effect === undefined) {
        const taggers = [newSub.__$onMessage];
        const effectId = eventListener.__$new(newSub.__$subId)((payload) => {

          for (const tagger of taggers) {
            _Platform_sendToApp(runtime)(__Utils_Tuple2(tagger(payload), __Platform_AsyncUpdate));
          }
        });
        managerState.set(newSub.__$subId, {
          __taggers: taggers,
          __effectId: effectId,
          __discontinued: eventListener.__$discontinued,
        });
      } else {
        effect.__taggers.push(newSub.__$onMessage);
      }
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

// command : (RuntimeId -> Platform.Task Never (Maybe msg)) -> Cmd msg
const _Platform_command = (createTask) => {
  return __Platform_initializeHelperFunctions.__$createCmd(createTask);
};

const _Platform_subscription = (key) => (tagger) => {
  return __Platform_initializeHelperFunctions.__$subscriptionHelper(key)(tagger);
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
/* global __Maybe_Nothing */
/* global __Platform_initializeHelperFunctions, __Platform_AsyncUpdate, __Platform_SyncUpdate */
/* global __RawTask_execImpure, __RawTask_syncBinding */
