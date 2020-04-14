/*

import Maybe exposing (Just, Nothing)
import Elm.Kernel.Debug exposing (crash, runtimeCrashReason)
import Elm.Kernel.Utils exposing (Tuple2)
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
  return __Utils_Tuple2(_Channel_rawSendImpl(id), id);
};

const _Channel_rawTryRecv = (channelId) => {
  const channel = _Channel_channels.get(channelId);
  /**__DEBUG/
	if (channel === undefined) {
		__Debug_crash(12, __Debug_runtimeCrashReason('channelIdNotRegistered'), channelId && channelId.a && channelId.a.__$id);
	}
	//*/
  const msg = channel.messages.shift();
  if (msg === undefined) {
    return __Maybe_Nothing;
  } else {
    return __Maybe_Just(msg);
  }
};

const _Channel_rawRecv = F2((channelId, onMsg) => {
  const channel = _Channel_channels.get(channelId);
  /**__DEBUG/
	if (channel === undefined) {
		__Debug_crash(12, __Debug_runtimeCrashReason('channelIdNotRegistered'), channelId && channelId.a && channelId.a.__$id);
	}
	//*/
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

const _Channel_rawSendImpl = F2((channelId, msg) => {
  const channel = _Channel_channels.get(channelId);
  /**__DEBUG/
	if (channel === undefined) {
		__Debug_crash(12, __Debug_runtimeCrashReason('channelIdNotRegistered'), channelId && channelId.a && channelId.a.__$id);
	}
	//*/

  const wakerIter = channel.wakers[Symbol.iterator]();
  const { value: nextWaker, done } = wakerIter.next();
  if (done) {
    channel.messages.push(msg);
  } else {
    channel.wakers.delete(nextWaker);
    nextWaker(msg);
  }
  return _Utils_Tuple0;
});

const _Channel_rawSend = F2((sender, msg) => {
  sender(msg);
});
