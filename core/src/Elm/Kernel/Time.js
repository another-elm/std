/*

import Time exposing (customZone, Name)
import Elm.Kernel.List exposing (Nil)
import Elm.Kernel.Platform exposing (createSubProcess)
import Platform.Scheduler as Scheduler exposing (execImpure)
import Elm.Kernel.Channel exposing (rawSend)
import Elm.Kernel.Utils exposing (Tuple0)

*/

function _Time_rawNow() {
  return Date.now();
}

/**
 *
 * This function is pure as timeout will not be set until a command with the
 * right key finds its way into the update loop.
 */
function _Time_setInterval(interval) {
  // TODO(harry): consider overhead of the fmod call.
  // TODO(harry): consider floating point rounding issues.
  let handle = null;

  const restart = () => {
    const now = _Time_rawNow();
    handle = setTimeout(() => {
      handle = null;
      key.send(_Time_rawNow());
    }, interval - (now % interval));
  };

  // Cancel non-subscribed-to timeouts. Start subscribed-to
  // previously-cancelled timeouts.
  const onSubReset = (n) => {
    if (n === 0) {
      if (handle !== null) {
        clearTimeout(handle);
      }
    } else {
      if (handle === null) {
        restart();
      }
    }
    return __Utils_Tuple0;
  };

  const key = __Platform_createSubProcess(onSubReset);

  return key;
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
