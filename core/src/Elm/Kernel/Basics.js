/*

import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)

*/

// MATH

const _Basics_pow = F2(Math.pow);

const _Basics_cos = Math.cos;
const _Basics_sin = Math.sin;
const _Basics_tan = Math.tan;
const _Basics_acos = Math.acos;
const _Basics_asin = Math.asin;
const _Basics_atan = Math.atan;
const _Basics_atan2 = F2(Math.atan2);

const _Basics_ceiling = Math.ceil;
const _Basics_floor = Math.floor;
const _Basics_round = Math.round;
const _Basics_sqrt = Math.sqrt;
const _Basics_log = Math.log;

const _Basics_modBy0 = () => __Debug_crash(11);

const _Basics_fudgeType = (x) => x;

const _Basics_unwrapTypeWrapper__DEBUG = (wrapped) => {
  const entries = Object.entries(wrapped);
  if (entries.length !== 2) {
    __Debug_crash(12, __Debug_runtimeCrashReason("failedUnwrap"), wrapped);
  }
  if (entries[0][0] === "$") {
    return entries[1][1];
  } else {
    return entries[0][1];
  }
};

const _Basics_unwrapTypeWrapper__PROD = (wrapped) => wrapped;

const _Basics_isDebug__DEBUG = true;
const _Basics_isDebug__PROD = false;

const _Basics_valueStore = initialValue => {
  let value = initialValue;
  return (stepper1) => {
    const tuple = stepper1(value);
    value = tuple.b;
    return tuple.a;
  }
}
