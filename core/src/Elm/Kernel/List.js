/*

import Basics exposing (EQ, LT)
import List exposing (Nil_elm_builtin, Cons_elm_builtin)

*/

/* Ideally we would write
 *
 * ```
 * const \_List_Nil = \_\_List_Nil;
 * ```
 *
 * to forward this call `elm/core:List.Nil_elm_builtin` however the elm
 * compiler puts the javascript for `elm/core:List.Nil_elm_builtin` after the
 * javascript below in the elm.js file and so with the above definition we get
 * "XXX is undefined" errors.
 *
 * We also cannot use Elm.Kernel.Basics.isDebug as we get into circular
 * dependancy issues:
 *
 * We have kernel dependencies that look like
 *
 *      Basics <---
 *        |       |
 *        v       |/
 *      Debug     /
 *        |      /|
 *        v       |
 *      List ------
 *
 *
 */
/* eslint-disable-next-line no-constant-condition */
const _List_nilKey = "__DEBUG" === "" ? "Nil_elm_builtin" : 0;
const _List_Nil = { $: _List_nilKey };

const _List_Cons = (hd, tl) => A2(__List_Cons_elm_builtin, hd, tl);

const _List_fromArray = (array) =>
  array.reduceRight(
    (out, value) => A2(__List_Cons_elm_builtin, value, out),
    __List_Nil_elm_builtin
  );

function* _List_iterate(xs) {
  for (;;) {
    if (xs.$ === _List_nilKey) {
      return;
    }

    yield xs.a;
    xs = xs.b;
  }
}

const _List_toArray = (xs) => {
  return [..._List_iterate(xs)];
};

const _List_sortWith = F2((f, xs) =>
  _List_fromArray(
    _List_toArray(xs).sort((a, b) => {
      const ord = A2(f, a, b);
      return ord === __Basics_EQ ? 0 : ord === __Basics_LT ? -1 : 1;
    })
  )
);

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_List_.*" }] */

/* global __Basics_EQ, __Basics_LT */
/* global __List_Nil_elm_builtin, __List_Cons_elm_builtin */
