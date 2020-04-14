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
 */
const _List_nilKey__PROD = 0;
const _List_nilKey__DEBUG = "Nil_elm_builtin";
const _List_Nil = { $: _List_nilKey };

const _List_Cons = (hd, tl) => A2(__List_Cons_elm_builtin, hd, tl);

const _List_fromArray = (arr) =>
  arr.reduceRight((out, val) => A2(__List_Cons_elm_builtin, val, out), __List_Nil_elm_builtin);

const _List_toArray = (xs) => {
  const out = [];
  while (true) {
    if (xs.$ === _List_nilKey) {
      return out;
    }
    out.push(xs.a);
    xs = xs.b;
  }
};

const _List_sortWith = F2((f, xs) =>
  _List_fromArray(
    _List_toArray(xs).sort((a, b) => {
      const ord = A2(f, a, b);
      return ord === __Basics_EQ ? 0 : ord === __Basics_LT ? -1 : 1;
    })
  )
);
