/*

import Elm.Kernel.Basics exposing (isDebug)
import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Utils exposing (Tuple0)

*/

const _Channel_channels = new WeakMap();
let _Channel_channelId = 0;

const _Channel_rawUnbounded = (_) => {
  const id = {
    id: _Channel_channelId++,
  };
  _Channel_channels.set(id, {
    messages: [],
    wakers: new Set(),
  });
  return id;
};

const _Channel_rawRecv = F2((channelId, onMsg) => {
  const channel = _Channel_channels.get(channelId);
  if (__Basics_isDebug && channel === undefined) {
    __Debug_crash(
      12,
      __Debug_runtimeCrashReason("channelIdNotRegistered"),
      channelId && channelId.id
    );
  }
  const msg = channel.messages.shift();
  if (msg !== undefined) {
    onMsg(msg);
    return (x) => x;
  }
  const onWake = (msg) => {
    return onMsg(msg);
  };
  channel.wakers.add(onWake);
  return (x) => {
    channel.wakers.delete(onWake);
    return x;
  };
});

const _Channel_rawSend = F2((sender, msg) => {
  const channel = _Channel_channels.get(sender);
  if (__Basics_isDebug && channel === undefined) {
    __Debug_crash(12, __Debug_runtimeCrashReason("channelIdNotRegistered"), sender && sender.id);
  }

  const wakerIter = channel.wakers[Symbol.iterator]();
  const { value: nextWaker, done } = wakerIter.next();
  if (done) {
    channel.messages.push(msg);
  } else {
    channel.wakers.delete(nextWaker);
    nextWaker(msg);
  }
  return __Utils_Tuple0;
});
