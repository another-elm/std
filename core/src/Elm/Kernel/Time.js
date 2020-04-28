/*

import Time exposing (customZone, Name)
import Elm.Kernel.List exposing (Nil)
import Elm.Kernel.Platform exposing (createSubProcess)
import Platform.Scheduler as Scheduler exposing (execImpure)
import Elm.Kernel.Channel exposing (rawSend)
import Elm.Kernel.Utils exposing (Tuple0)

*/

function _Time_now(millisToPosix) {
  return __Scheduler_execImpure((_) => millisToPosix(Date.now()));
}

const _Time_intervals = new WeakMap();

/**
 * There is no way to do clean up in js. This implementation is fundamentally
 * broken as the intervals created are never cleaned up. TODO(harry): fix this.
 *
 * This function is impure and should _really_ return a Task. That would be a
 * breaking API change though.
 */
function _Time_setInterval(interval) {
  const roundedInterval = Math.round(interval);
  const existingKey = _Time_intervals.get(roundedInterval);
  if (existingKey !== undefined) {
    return existingKey;
  } else {
    const handle = setInterval(() => {
      A2(__Channel_rawSend, sender, Date.now());
    }, roundedInterval);

    // Unless we are carefull here, creating any Time.every subscription has
    // the potential of preventing and elm app from terminating when we run in
    // nodejs. We use the node specific [`TimeOut.ref()`](ref) and
    // [`TimeOut.unref()`](unref) API's to ensure our app terminates.
    //
    // [ref]: https://nodejs.org/api/timers.html#timers_timeout_ref
    // [unref]: https://nodejs.org/api/timers.html#timers_timeout_unref
    const onSubReset =
      typeof handle.ref === "function"
        ? (n) => {
            if (n == 0) {
              handle.unref();
            } else {
              handle.ref();
            }
            return __Utils_Tuple0;
          }
        : (_) => __Utils_Tuple0;

    const tuple = __Platform_createSubProcess(onSubReset);
    const key = tuple.a;
    const sender = tuple.b;

    return key;
  }
}

function _Time_here() {
  return __Scheduler_execImpure((_) =>
    A2(__Time_customZone, -new Date().getTimezoneOffset(), __List_Nil)
  );
}

function _Time_getZoneName() {
  return __Scheduler_execImpure((_) =>
    __Time_Name(Intl.DateTimeFormat().resolvedOptions().timeZone)
  );
}
