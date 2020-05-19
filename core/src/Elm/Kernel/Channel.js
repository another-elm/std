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

const _Channel_rawRecv = F2((channelId, onMessage) => {
  const channel = _Channel_channels.get(channelId);
  if (__Basics_isDebug && channel === undefined) {
    __Debug_crash(
      12,
      __Debug_runtimeCrashReason("channelIdNotRegistered"),
      channelId && channelId.id
    );
  }

  const message = channel.messages.shift();
  if (message !== undefined) {
    onMessage(message);
    return (x) => x;
  }

  const onWake = (message) => {
    return onMessage(message);
  };

  channel.wakers.add(onWake);
  return (x) => {
    channel.wakers.delete(onWake);
    return x;
  };
});

const _Channel_rawSend = F2((sender, message) => {
  const channel = _Channel_channels.get(sender);
  if (__Basics_isDebug && channel === undefined) {
    __Debug_crash(12, __Debug_runtimeCrashReason("channelIdNotRegistered"), sender && sender.id);
  }

  const wakerIter = channel.wakers[Symbol.iterator]();
  const { value: nextWaker, done } = wakerIter.next();
  if (done) {
    channel.messages.push(message);
  } else {
    channel.wakers.delete(nextWaker);
    nextWaker(message);
  }

  return __Utils_Tuple0;
});
