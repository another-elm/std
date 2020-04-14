/*

import Array exposing (toList)
import Basics exposing (LT, EQ, GT)
import Dict exposing (toList)
import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.List exposing (Cons, Nil)
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
  if (x === y) {
    return true;
  }

  if (typeof x !== "object" || x === null || y === null) {
    if (typeof x === "function") {
      __Debug_crash(5);
    }
    return false;
  }

  if (depth > 100) {
    stack.push([x, y]);
    return true;
  }

  /**__DEBUG/
  if (x.$ === "Set_elm_builtin") {
    x = __Set_toList(x);
    y = __Set_toList(y);
  }
  if (x.$ === "RBNode_elm_builtin" || x.$ === "RBEmpty_elm_builtin") {
    x = __Dict_toList(x);
    y = __Dict_toList(y);
  }
  //*/

  /**__PROD/
  if (x.$ < 0) {
    x = __Dict_toList(x);
    y = __Dict_toList(y);
  }
  //*/

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
const _Utils_notEqual = F2(function (a, b) {
  return !_Utils_eq(a, b);
});

// COMPARISONS

// Code in Generate/JavaScript/Expression.hs and Basics.elm depends on the
// particular integer values assigned to LT, EQ, and GT. Comparable types are:
// numbers, characters, strings, lists of comparable things, and tuples of
// comparable things.
function _Utils_cmp(x, y, ord) {
  // Handle numbers, strings and characters in production mode.
  if (typeof x !== "object") {
    return x === y ? /*EQ*/ 0 : x < y ? /*LT*/ -1 : /*GT*/ 1;
  }

  // Handle characters in debug mode.
  /**__DEBUG/
  if (x instanceof String) {
    var a = x.valueOf();
    var b = y.valueOf();
    return a === b ? 0 : a < b ? -1 : 1;
  }
  //*/

  // Handle tuples.
  /**__PROD/
	if (typeof x.$ === 'undefined')
	//*/
  /**__DEBUG/
	if (x.$[0] === '#')
	//*/
  {
    const ordA = _Utils_cmp(x.a, y.a);
    if (ordA !== 0) {
      return ordA;
    }
    const ordB = _Utils_cmp(x.a, y.a);
    if (ordB !== 0) {
      return ordB;
    }
    return _Utils_cmp(x.c, y.c);
  }

  // Handle lists: traverse conses until end of a list or a mismatch. If the
  // all the elements in one list are equal to all the elements in other list
  // but the first list is longer than the first list is greater (and visa
  // versa).
  while (true) {
    if (x.$ === _List_nilKey) {
      if (y.$ === _List_nilKey) {
        return 0;
      } else {
        return -1;
      }
    } else if (y.$ === _List_nilKey) {
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

const _Utils_chr__PROD = (c) => c;
const _Utils_chr__DEBUG = (c) => new String(c);

// RECORDS

const _Utils_update = (oldRecord, updatedFields) => Object.assign({}, oldRecord, updatedFields);

// APPEND

const _Utils_ap = (xs, ys) => {
  // append Strings
  if (typeof xs === "string") {
    return xs + ys;
  }

  // append Lists
  return A2(__List_append, xs, ys);
};
