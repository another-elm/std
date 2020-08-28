/*

import Dict exposing (empty, update)
import Elm.Kernel.Scheduler exposing (binding, fail, rawSpawn, succeed)
import Elm.Kernel.Utils exposing (Tuple2)
import Http exposing (BadUrl_, Timeout_, NetworkError_, BadStatus_, GoodStatus_, Sending, Receiving)
import Maybe exposing (Just, Nothing, isJust)
import Platform exposing (sendToApp, sendToSelf)
import Result exposing (map, isOk)

*/

/* eslint-disable */

// SEND REQUEST

const _Http_toTask = F3(function (router, toTask, request) {
  return __Scheduler_binding(function (callback) {
    function done(response) {
      callback(toTask(request.__$expect.__toValue(response)));
    }

    const xhr = new XMLHttpRequest();
    xhr.addEventListener("error", function () {
      done(__Http_NetworkError_);
    });
    xhr.addEventListener("timeout", function () {
      done(__Http_Timeout_);
    });
    xhr.addEventListener("load", function () {
      done(_Http_toResponse(request.__$expect.__toBody, xhr));
    });
    __Maybe_isJust(request.__$tracker) && _Http_track(router, xhr, request.__$tracker.a);

    try {
      xhr.open(request.__$method, request.__$url, true);
    } catch (error) {
      return done(__Http_BadUrl_(request.__$url));
    }

    _Http_configureRequest(xhr, request);

    request.__$body.a && xhr.setRequestHeader("Content-Type", request.__$body.a);
    xhr.send(request.__$body.b);

    return function () {
      xhr.__isAborted = true;
      xhr.abort();
    };
  });
});

// CONFIGURE

function _Http_configureRequest(xhr, request) {
  for (
    let headers = request.__$headers;
    headers.b;
    headers = headers.b // WHILE_CONS
  ) {
    xhr.setRequestHeader(headers.a.a, headers.a.b);
  }

  xhr.timeout = request.__$timeout.a || 0;
  xhr.responseType = request.__$expect.__type;
  xhr.withCredentials = request.__$allowCookiesFromOtherDomains;
}

// RESPONSES

function _Http_toResponse(toBody, xhr) {
  return A2(
    xhr.status >= 200 && xhr.status < 300 ? __Http_GoodStatus_ : __Http_BadStatus_,
    _Http_toMetadata(xhr),
    toBody(xhr.response)
  );
}

// METADATA

function _Http_toMetadata(xhr) {
  return {
    __$url: xhr.responseURL,
    __$statusCode: xhr.status,
    __$statusText: xhr.statusText,
    __$headers: _Http_parseHeaders(xhr.getAllResponseHeaders()),
  };
}

// HEADERS

function _Http_parseHeaders(rawHeaders) {
  if (!rawHeaders) {
    return __Dict_empty;
  }

  let headers = __Dict_empty;
  const headerPairs = rawHeaders.split("\r\n");
  for (let i = headerPairs.length; i--; ) {
    const headerPair = headerPairs[i];
    const index = headerPair.indexOf(": ");
    if (index > 0) {
      const key = headerPair.slice(0, Math.max(0, index));
      var value = headerPair.slice(Math.max(0, index + 2));

      headers = A3(
        __Dict_update,
        key,
        function (oldValue) {
          return __Maybe_Just(__Maybe_isJust(oldValue) ? value + ", " + oldValue.a : value);
        },
        headers
      );
    }
  }

  return headers;
}

// EXPECT

const _Http_expect = F3(function (type, toBody, toValue) {
  return {
    $: 0,
    __type: type,
    __toBody: toBody,
    __toValue: toValue,
  };
});

const _Http_mapExpect = F2(function (func, expect) {
  return {
    $: 0,
    __type: expect.__type,
    __toBody: expect.__toBody,
    __toValue(x) {
      return func(expect.__toValue(x));
    },
  };
});

function _Http_toDataView(arrayBuffer) {
  return new DataView(arrayBuffer);
}

// BODY and PARTS

const _Http_emptyBody = { $: 0 };
const _Http_pair = F2(function (a, b) {
  return { $: 0, a, b };
});

function _Http_toFormData(parts) {
  for (
    var formData = new FormData();
    parts.b;
    parts = parts.b // WHILE_CONS
  ) {
    const part = parts.a;
    formData.append(part.a, part.b);
  }

  return formData;
}

const _Http_bytesToBlob = F2(function (mime, bytes) {
  return new Blob([bytes], { type: mime });
});

// PROGRESS

function _Http_track(router, xhr, tracker) {
  // TODO check out lengthComputable on loadstart event

  xhr.upload.addEventListener("progress", function (event) {
    if (xhr.__isAborted) {
      return;
    }

    __Scheduler_rawSpawn(
      A2(
        __Platform_sendToSelf,
        router,
        __Utils_Tuple2(
          tracker,
          __Http_Sending({
            __$sent: event.loaded,
            __$size: event.total,
          })
        )
      )
    );
  });
  xhr.addEventListener("progress", function (event) {
    if (xhr.__isAborted) {
      return;
    }

    __Scheduler_rawSpawn(
      A2(
        __Platform_sendToSelf,
        router,
        __Utils_Tuple2(
          tracker,
          __Http_Receiving({
            __$received: event.loaded,
            __$size: event.lengthComputable ? __Maybe_Just(event.total) : __Maybe_Nothing,
          })
        )
      )
    );
  });
}

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Http_.*" }] */

/* global __Dict_empty, __Dict_update */
/* global __Scheduler_binding, __Scheduler_fail, __Scheduler_rawSpawn, __Scheduler_succeed */
/* global __Utils_Tuple2 */
/* global __Http_BadUrl_, __Http_Timeout_, __Http_NetworkError_, __Http_BadStatus_, __Http_GoodStatus_, __Http_Sending, __Http_Receiving */
/* global __Maybe_Just, __Maybe_Nothing, __Maybe_isJust */
/* global __Platform_sendToApp, __Platform_sendToSelf */
/* global __Result_map, __Result_isOk */
