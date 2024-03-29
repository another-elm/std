/*

import Dict exposing (toList)
import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.List exposing (nilKey)
import Elm.Kernel.Basics exposing (isDebug)
import Set exposing (toList)
import List exposing (append)

*/

// EQUALITY

const _Utils_eq = (x, y) => {
  const stack = [];
  while (_Utils_eqHelp(x, y, 0, stack)) {
    const pair = stack.pop();
    if (pair === undefined) {
      return true;
    }

    [x, y] = pair;
  }

  return false;
};

function _Utils_eqHelp(x, y, depth, stack) {
  if (typeof x === "function") {
    __Debug_crash(5);
  }

  if (x === y) {
    // Only do equal object in debug mode to catch nested functions and provide
    // helpful errors to devs.
    if (!(__Basics_isDebug && typeof x === "object")) {
      return true;
    }
  }

  if (typeof x !== "object" || x === null || y === null) {
    return false;
  }

  if (depth > 100) {
    stack.push([x, y]);
    return true;
  }

  if (__Basics_isDebug) {
    if (x.$ === "Set_elm_builtin") {
      x = __Set_toList(x);
      y = __Set_toList(y);
    } else if (x.$ === "RBNode_elm_builtin" || x.$ === "RBEmpty_elm_builtin") {
      x = __Dict_toList(x);
      y = __Dict_toList(y);
    }
  } else if (x.$ < 0) {
    x = __Dict_toList(x);
    y = __Dict_toList(y);
  }

  if (typeof DataView === "function" && x instanceof DataView) {
    const length = x.byteLength;

    if (y.byteLength !== length) {
      return false;
    }

    for (let i = 0; i < length; ++i) {
      if (x.getUint8(i) !== y.getUint8(i)) {
        return false;
      }
    }
  }

  /* The compiler ensures that the elm types of x and y are the same.
   * Therefore, x and y must have the same keys.
   */
  for (const key of Object.keys(x)) {
    if (!_Utils_eqHelp(x[key], y[key], depth + 1, stack)) {
      return false;
    }
  }

  return true;
}

const _Utils_equal = F2(_Utils_eq);
const _Utils_notEqual = F2((a, b) => {
  return !_Utils_eq(a, b);
});

// COMPARISONS

// Code in Generate/JavaScript/Expression.hs and Basics.elm depends on the
// particular integer values assigned to LT, EQ, and GT. Comparable types are:
// numbers, characters, strings, lists of comparable things, and tuples of
// comparable things.
function _Utils_cmp(x, y) {
  // Handle numbers, strings and characters in production mode.
  if (typeof x !== "object") {
    return x === y ? /* EQ */ 0 : x < y ? /* LT */ -1 : /* GT */ 1;
  }

  // Handle characters in debug mode.
  if (__Basics_isDebug && x instanceof String) {
    const a = x.valueOf();
    const b = y.valueOf();
    return a === b ? 0 : a < b ? -1 : 1;
  }

  // Handle tuples.
  const isTuple = __Basics_isDebug ? x.$[0] === "#" : x.$ === undefined;
  if (isTuple) {
    const ordA = _Utils_cmp(x.a, y.a);
    if (ordA !== 0) {
      return ordA;
    }

    const ordB = _Utils_cmp(x.b, y.b);
    if (ordB !== 0) {
      return ordB;
    }

    return _Utils_cmp(x.c, y.c);
  }

  // Handle lists: traverse conses until end of a list or a mismatch. If the
  // all the elements in one list are equal to all the elements in other list
  // but the first list is longer than the first list is greater (and visa
  // versa).
  for (;;) {
    if (x.$ === __List_nilKey) {
      if (y.$ === __List_nilKey) {
        return 0;
      }

      return -1;
    }

    if (y.$ === __List_nilKey) {
      return 1;
    }

    const ord = _Utils_cmp(x.a, y.a);
    if (ord !== 0) {
      return ord;
    }

    x = x.b;
    y = y.b;
  }
}

const _Utils_compare = F2((x, y) => _Utils_cmp(x, y));

// COMMON VALUES

const _Utils_Tuple0__PROD = 0;
const _Utils_Tuple0__DEBUG = { $: "#0" };

const _Utils_Tuple2__PROD = (a, b) => ({ a, b });
const _Utils_Tuple2__DEBUG = (a, b) => ({ $: "#2", a, b });

const _Utils_Tuple3__PROD = (a, b, c) => ({ a, b, c });
const _Utils_Tuple3__DEBUG = (a, b, c) => ({ $: "#3", a, b, c });

const _Utils_tuple2iter = (tup) => [tup.a, tup.b];

const _Utils_chr__PROD = (c) => c;
const _Utils_chr__DEBUG = (c) => new Object(c);

// RECORDS

const _Utils_update = (oldRecord, updatedFields) => Object.assign({}, oldRecord, updatedFields);

// APPEND

const _Utils_ap = (xs, ys) => {
  // Append Strings
  if (typeof xs === "string") {
    return xs + ys;
  }

  // Append Lists
  return A2(__List_append, xs, ys);
};

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Utils_.*" }] */

/* global __Dict_toList */
/* global __Debug_crash */
/* global __List_nilKey */
/* global __Basics_isDebug */
/* global __Set_toList */
/* global __List_append */
