/*

import Dict exposing (empty, update)
import Http exposing (BadUrl_, Timeout_, NetworkError_, BadStatus_, GoodStatus_, Sending, Receiving)
import Maybe exposing (Just, Nothing, isJust)
import Elm.Kernel.Platform exposing (sendToApp)
import Elm.Kernel.List exposing (iterate)

*/

// SEND REQUEST

const _Http_makeRequest = (request) => {
  function done(response) {
    request.__$onComplete(response);
  }

  const xhr = new XMLHttpRequest();
  xhr.addEventListener("error", function () {
    done(__Http_NetworkError_);
  });
  xhr.addEventListener("timeout", function () {
    done(__Http_Timeout_);
  });
  xhr.addEventListener("load", function () {
    done(_Http_toResponse(request.__$toBody, xhr));
  });

  const cancel = () => {
    xhr.__isAborted = true;
    xhr.abort();
    request.__$onCancel();
  };

  if (__Maybe_isJust(request.__$tracker)) {
    _Http_trackRequest(
      request.__$tracker.a.a,
      request.__$tracker.a.b,
      request.__$managerId,
      xhr,
      cancel
    );
  }

  try {
    xhr.open(request.__$method, request.__$url, true);
  } catch (error) {
    return done(__Http_BadUrl_(request.__$url));
  }

  if (__Maybe_isJust(request.__$contentType)) {
    xhr.setRequestHeader("Content-Type", request.__$contentType.a);
  }

  _Http_configureRequest(xhr, request.__$config);

  xhr.send(request.__$body);

  return { cancel };
};

// CONFIGURE

function _Http_configureRequest(xhr, request) {
  for (const header of __List_iterate(request.__$headers)) {
    xhr.setRequestHeader(header.a, header.b);
  }

  xhr.timeout = request.__$timeout;
  xhr.responseType = request.__$responseType;
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
  for (const headerPair of headerPairs) {
    const index = headerPair.indexOf(": ");
    if (index > 0) {
      const key = headerPair.slice(0, index);
      const value = headerPair.slice(index + 2);

      headers = A3(
        __Dict_update,
        key,
        (oldValue) => __Maybe_Just(__Maybe_isJust(oldValue) ? oldValue.a + ", " + value : value),
        headers
      );
    }
  }

  return headers;
}

// EXPECT

function _Http_toDataView(arrayBuffer) {
  return new DataView(arrayBuffer);
}

// BODY and PARTS

const _Http_emptyBodyContents = null;

function _Http_multipartBodyContents(parts) {
  const formData = new FormData();
  for (const part of __List_iterate(parts)) {
    formData.append(part.a, part.b);
  }

  return formData;
}

const _Http_bytesToBlob = F2(function (mime, bytes) {
  return new Blob([bytes], { type: mime });
});

// PROGRESS

function _Http_trackRequest(runtime, tracker, managerId, xhr, cancel) {
  // TODO check out lengthComputable on loadstart event

  let taggers = runtime.__runtimeSubscriptionHandlers.get(managerId);
  if (taggers === undefined) {
    taggers = [];
    runtime.__runtimeSubscriptionHandlers.set(managerId, taggers);
  }

  xhr.upload.addEventListener("progress", function (event) {
    if (xhr.__isAborted) {
      return;
    }

    for (const tagger of taggers) {
      __Platform_sendToApp(runtime)(
        tagger(tracker)(
          __Http_Sending({
            __$sent: event.loaded,
            __$size: event.total,
          })
        )
      );
    }
  });
  xhr.addEventListener("progress", function (event) {
    if (xhr.__isAborted) {
      return;
    }

    for (const tagger of taggers) {
      __Platform_sendToApp(runtime)(
        tagger(tracker)(
          __Http_Receiving({
            __$received: event.loaded,
            __$size: event.lengthComputable ? __Maybe_Just(event.total) : __Maybe_Nothing,
          })
        )
      );
    }
  });

  _Http_registerCancel(runtime, tracker, cancel);
}

const _Http_tracking = new WeakMap();

const _Http_registerCancel = (runtimeId, trackingId, cancel) => {
  let runtimeTracking = _Http_tracking.get(runtimeId);
  if (runtimeTracking === undefined) {
    runtimeTracking = new Map();
    _Http_tracking.set(runtimeId, runtimeTracking);
  }

  runtimeTracking.set(trackingId, cancel);
};

const _Http_cancel = (runtimeId) => (trackingId) => {
  const runtimeTracking = _Http_tracking.get(runtimeId);
  if (runtimeTracking !== undefined) {
    const cancel = runtimeTracking.get(trackingId);
    if (cancel !== undefined) {
      cancel();
    }
  }
};

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Http_.*" }] */

/* global __Dict_empty, __Dict_update */
/* global __Http_BadUrl_, __Http_Timeout_, __Http_NetworkError_, __Http_BadStatus_, __Http_GoodStatus_, __Http_Sending, __Http_Receiving */
/* global __Maybe_Just, __Maybe_Nothing, __Maybe_isJust */
/* global __Platform_sendToApp */
/* global __List_iterate */
