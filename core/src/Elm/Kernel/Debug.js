/*

import Array exposing (toList)
import Dict exposing (toList)
import Set exposing (toList)
import Elm.Kernel.List exposing (toArray)

*/

/* global scope */

/* global _Debug_toString, _Debug_crash
 */

// LOG

const _Debug_log__PROD = F2((tag, value) => {
  return value;
});

const _Debug_log__DEBUG = (tag) => {
  const p = Promise.reject(new Error("you must pass this function two arguments!"));
  return (value) => {
    const log =
      typeof scope !== "undefined" && Object.prototype.hasOwnProperty.call(scope, `_debugLog`)
        ? scope._debugLog
        : console.log;

    p.catch((error) => error);
    log(tag + ": " + _Debug_toString(value));
    return value;
  };
};

// TODOS

function _Debug_todo(moduleName, region) {
  return function (message) {
    _Debug_crash(8, moduleName, region, message);
  };
}

function _Debug_todoCase(moduleName, region, value) {
  return function (message) {
    _Debug_crash(9, moduleName, region, value, message);
  };
}

// TO STRING

function _Debug_toString__PROD() {
  return "<internals>";
}

function _Debug_toString__DEBUG(value) {
  return _Debug_toAnsiString(false, value);
}

function _Debug_toAnsiString(ansi, value) {
  if (typeof value === "function") {
    return _Debug_internalColor(ansi, "<function>");
  }

  if (typeof value === "boolean") {
    return _Debug_ctorColor(ansi, value ? "True" : "False");
  }

  if (typeof value === "number") {
    return _Debug_numberColor(ansi, String(value));
  }

  if (value instanceof String) {
    return _Debug_charColor(ansi, "'" + _Debug_addSlashes(value, true) + "'");
  }

  if (typeof value === "string") {
    return _Debug_stringColor(ansi, '"' + _Debug_addSlashes(value, false) + '"');
  }

  if (typeof value === "object" && "$" in value) {
    const tag = value.$;

    if (typeof tag === "number") {
      return _Debug_internalColor(ansi, "<internals>");
    }

    if (tag[0] === "#") {
      const output = [];
      for (const [k, v] of Object.entries(value)) {
        if (k === "$") continue;
        output.push(_Debug_toAnsiString(ansi, v));
      }

      return "(" + output.join(",") + ")";
    }

    if (tag === "Set_elm_builtin") {
      return (
        _Debug_ctorColor(ansi, "Set") +
        _Debug_fadeColor(ansi, ".fromList") +
        " " +
        _Debug_toAnsiString(ansi, __Set_toList(value))
      );
    }

    if (tag === "RBNode_elm_builtin" || tag === "RBEmpty_elm_builtin") {
      return (
        _Debug_ctorColor(ansi, "Dict") +
        _Debug_fadeColor(ansi, ".fromList") +
        " " +
        _Debug_toAnsiString(ansi, __Dict_toList(value))
      );
    }

    if (tag === "Array_elm_builtin") {
      return (
        _Debug_ctorColor(ansi, "Array") +
        _Debug_fadeColor(ansi, ".fromList") +
        " " +
        _Debug_toAnsiString(ansi, __Array_toList(value))
      );
    }

    if (tag === "Cons_elm_builtin" || tag === "Nil_elm_builtin") {
      return (
        "[" +
        __List_toArray(value)
          .map((v) => _Debug_toAnsiString(ansi, v))
          .join(",") +
        "]"
      );
    }

    const parts = Object.entries(value).map(([k, v]) => {
      if (k === "$") {
        return _Debug_ctorColor(ansi, v);
      }

      const string = _Debug_toAnsiString(ansi, v);
      const c0 = string[0];
      const parenless =
        c0 === "{" || c0 === "(" || c0 === "[" || c0 === "<" || c0 === '"' || !string.includes(" ");
      return parenless ? string : "(" + string + ")";
    });
    return parts.join(" ");
  }

  if (typeof DataView === "function" && value instanceof DataView) {
    const bytes = new Uint8Array(value.buffer);
    const suffix = bytes.length > 10 ? " ..." : "";

    return _Debug_stringColor(
      ansi,
      "<" +
        value.byteLength +
        " bytes: " +
        Array.from(bytes.slice(0, 10))
          .map((i) => i.toString(16))
          .join(" ") +
        suffix +
        ">"
    );
  }

  if (typeof File !== "undefined" && value instanceof File) {
    return _Debug_internalColor(ansi, "<" + value.name + ">");
  }

  if (typeof value === "object") {
    const keyValuePairs = Object.entries(value).map(([k, v]) => {
      const field = k[0] === "_" ? k.slice(1) : k;
      return _Debug_fadeColor(ansi, field) + " = " + _Debug_toAnsiString(ansi, v);
    });
    return "{ " + keyValuePairs.join(", ") + " }";
  }

  return _Debug_internalColor(ansi, "<internals>");
}

function _Debug_addSlashes(string, isChar) {
  const s = string
    .replace(/\\/g, "\\\\")
    .replace(/\n/g, "\\n")
    .replace(/\t/g, "\\t")
    .replace(/\r/g, "\\r")
    .replace(/\v/g, "\\v")
    .replace(/\0/g, "\\0");

  if (isChar) {
    return s.replace(/'/g, "\\'");
  }

  return s.replace(/"/g, '\\"');
}

function _Debug_ctorColor(ansi, string) {
  return ansi ? "\u001B[96m" + string + "\u001B[0m" : string;
}

function _Debug_numberColor(ansi, string) {
  return ansi ? "\u001B[95m" + string + "\u001B[0m" : string;
}

function _Debug_stringColor(ansi, string) {
  return ansi ? "\u001B[93m" + string + "\u001B[0m" : string;
}

function _Debug_charColor(ansi, string) {
  return ansi ? "\u001B[92m" + string + "\u001B[0m" : string;
}

function _Debug_fadeColor(ansi, string) {
  return ansi ? "\u001B[37m" + string + "\u001B[0m" : string;
}

function _Debug_internalColor(ansi, string) {
  return ansi ? "\u001B[36m" + string + "\u001B[0m" : string;
}

function _Debug_toHexDigit(n) {
  return String.fromCharCode(n < 10 ? 48 + n : 55 + n);
}

// CRASH

function _Debug_runtimeCrashReason__PROD() {}

function _Debug_runtimeCrashReason__DEBUG(reason) {
  switch (reason) {
    case "subMap":
      return function () {
        throw new Error(
          "Bug in elm runtime: attempting to subMap an effect from a command only effect module."
        );
      };

    case "cmdMap":
      return function () {
        throw new Error(
          "Bug in elm runtime: attempting to cmdMap an effect from a subscription only effect module."
        );
      };

    case "procIdAlreadyRegistered":
      return function (fact2) {
        throw new Error(`Bug in elm runtime: state for process ${fact2} is already registered!`);
      };

    case "procIdNotRegistered":
      return function (fact2) {
        throw new Error(`Bug in elm runtime: state for process ${fact2} been has not registered!`);
      };

    case "cannotBeStepped":
      return function (fact2) {
        throw new Error(
          `Bug in elm runtime: attempting to step process with id ${fact2} whilst it is processing an async action!`
        );
      };

    case "procIdAlreadyReady":
      return function (fact2, fact3) {
        throw new Error(
          `Bug in elm runtime: process ${fact2} already has a ready flag set (with value ${fact3}). Refusing to reset the value before it is cleared`
        );
      };

    case "subscriptionProcessMissing":
      return function (fact2) {
        throw new Error(
          `Bug in elm runtime: expected there to be a subscriptionProcess with id ${fact2}.`
        );
      };

    case "EffectModule":
      return function () {
        throw new Error(
          `Effect modules are not supported, if you are using elm/* libraries you will need to switch to a custom version.`
        );
      };

    case "PlatformLeaf":
      return function (home) {
        throw new Error(
          `Trying to create a command or a subscription for event manager ${home}.
Effect modules are not supported, if you are using elm/* libraries you will need to switch to a custom version.`
        );
      };

    case "procIdAlreadyInQueue":
      return function () {
        throw new Error(`A process has been added to queue but it is already in the queue!.`);
      };

    case "channelIdNotRegistered":
      return function () {
        throw new Error(`Trying to send to a channel that has not actually been created!.`);
      };

    case "alreadyLoaded":
      return function () {
        throw new Error(`Trying to setup an init task after init has finished!.`);
      };

    default:
      throw new Error(`Unknown reason for runtime crash: ${reason}!`);
  }
}

function _Debug_crash__PROD(identifier) {
  throw new Error("Error in whilst running elm app id:" + identifier);
}

function _Debug_crash__DEBUG(identifier, fact1, fact2, fact3, fact4) {
  switch (identifier) {
    case 0:
      throw new Error(
        'What node should I take over? In JavaScript I need something like:\n\n    Elm.Main.init({\n        node: document.getElementById("elm-node")\n    })\n\nYou need to do this with any Browser.sandbox or Browser.element program.'
      );

    case 1: {
      let href = "<unknown>";
      if (typeof document !== "undefined") {
        href = document.location.href;
      }

      throw new Error(
        "Browser.application programs cannot handle URLs like this:\n\n    " +
          href +
          "\n\nWhat is the root? The root of your file system? Try looking at this program with `elm reactor` or some other server."
      );
    }

    case 2: {
      const jsonErrorString = fact1;
      throw new Error(
        "Problem with the flags given to your Elm program on initialization.\n\n" + jsonErrorString
      );
    }

    case 3: {
      const portName = fact1;
      throw new Error(
        "There can only be one port named `" + portName + "`, but your program has multiple."
      );
    }

    case 4: {
      const portName = fact1;
      const problem = fact2;
      throw new Error(
        "Trying to send an unexpected type of value through port `" + portName + "`:\n" + problem
      );
    }

    case 5:
      throw new Error(
        'Trying to use `(==)` on functions.\nThere is no way to know if functions are "the same" in the Elm sense.\nRead more about this at https://package.elm-lang.org/packages/elm/core/latest/Basics#== which describes why it is this way and what the better version will look like.'
      );

    case 6: {
      const moduleName = fact1;
      throw new Error(
        "Your page is loading multiple Elm scripts with a module named " +
          moduleName +
          ". Maybe a duplicate script is getting loaded accidentally? If not, rename one of them so I know which is which!"
      );
    }

    case 8: {
      const moduleName = fact1;
      const region = fact2;
      const message = fact3;
      throw new Error(
        "TODO in module `" + moduleName + "` " + _Debug_regionToString(region) + "\n\n" + message
      );
    }

    case 9: {
      const moduleName = fact1;
      const region = fact2;
      const value = fact3;
      const message = fact4;
      throw new Error(
        "TODO in module `" +
          moduleName +
          "` from the `case` expression " +
          _Debug_regionToString(region) +
          "\n\nIt received the following value:\n\n    " +
          _Debug_toString(value).replace("\n", "\n    ") +
          "\n\nBut the branch that handles it says:\n\n    " +
          message.replace("\n", "\n    ")
      );
    }

    case 10:
      throw new Error("Bug in https://github.com/elm/virtual-dom/issues");

    case 11:
      throw new Error("Cannot perform mod 0. Division by zero error.");

    case 12: {
      fact1(fact2, fact3, fact4);
      throw new Error(`Unknown bug in elm runtime tag: ${fact1}!`);
    }

    default:
      throw new Error(`Unknown reason for crash: ${identifier}!`);
  }
}

function _Debug_regionToString(region) {
  if (region.__$start.__$line === region.__$end.__$line) {
    return "on line " + region.__$start.__$line;
  }

  return "on lines " + region.__$start.__$line + " through " + region.__$end.__$line;
}

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Debug_.*" }] */

/* global __Array_toList */
/* global __Dict_toList */
/* global __Set_toList */
/* global __List_toArray */
