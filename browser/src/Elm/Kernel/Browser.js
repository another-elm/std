/*

import Basics exposing (never)
import Browser exposing (Internal, External)
import Browser.Dom as Dom exposing (NotFound)
import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.Json exposing (runHelp)
import Elm.Kernel.List exposing (Nil)
import Elm.Kernel.Platform exposing (initialize, browserifiedSendToApp)Fb
import Elm.Kernel.Utils exposing (Tuple0, Tuple2)
import Elm.Kernel.VirtualDom exposing (appendChild, applyPatches, diff, doc, node, passiveSupported, render, divertHrefToApp, virtualize)
import Json.Decode as Json exposing (map)
import Maybe exposing (Just, Nothing)
import Result exposing (isOk)
import Task exposing (perform, succeed, fail)
import Process exposing (spawn)
import Url exposing (fromString)

*/

// ELEMENT

const _Browser_elementStepperBuilder = (view) => (runtime) => (args) => (initialModel) => () => {
  /* *__PROD/
	var domNode = args['node'];
	// */
  /* *__DEBUG/
	var domNode = args && args['node'] ? args['node'] : __Debug_crash(0);
	// */
  let currNode = __VirtualDom_virtualize(domNode);
  const eventNode = __Platform_browserifiedSendToApp(runtime);

  return _Browser_makeAnimator(initialModel, function (model) {
    const nextNode = view(model);
    const patches = __VirtualDom_diff(currNode, nextNode);
    domNode = __VirtualDom_applyPatches(domNode, currNode, patches, eventNode);
    currNode = nextNode;
  });
};

// DOCUMENT

const _Browser_documentStepperBuilder = (view) => (runtime) => (args) => (initialModel) => () => {
  const eventNode = __Platform_browserifiedSendToApp(runtime);
  let title = __VirtualDom_doc.title;
  let bodyNode = __VirtualDom_doc.body;
  let currNode = __VirtualDom_virtualize(bodyNode);
  return _Browser_makeAnimator(initialModel, function (model) {
    __VirtualDom_divertHrefToApp = divertHrefToApp;
    const doc = view(model);
    const nextNode = __VirtualDom_node("body")(__List_Nil)(doc.__$body);
    const patches = __VirtualDom_diff(currNode, nextNode);
    bodyNode = __VirtualDom_applyPatches(bodyNode, currNode, patches, eventNode);
    currNode = nextNode;
    __VirtualDom_divertHrefToApp = 0;
    if (title !== doc.__$title) {
      __VirtualDom_doc.title = doc.__$title;
      title = doc.__$title;
    }
  });
};

// ANIMATION

function _Browser_makeAnimator(model, draw) {
  draw(model);

  let state = __4_NO_REQUEST;

  function updateIfNeeded() {
    state =
      state === __4_EXTRA_REQUEST
        ? __4_NO_REQUEST
        : (requestAnimationFrame(updateIfNeeded), draw(model), __4_EXTRA_REQUEST);
  }

  return (nextModel) => (isSync) => () => {
    model = nextModel;

    isSync
      ? (draw(model), state === __4_PENDING_REQUEST && (state = __4_EXTRA_REQUEST))
      : (state === __4_NO_REQUEST && requestAnimationFrame(updateIfNeeded),
        (state = __4_PENDING_REQUEST));
  };
}

// APPLICATION

const _Browser_appStepperBuilder = (impl) => (runtime) => (args) => (initialModel) => () => {
  const eventNode = __Platform_browserifiedSendToApp(runtime);
  let title = __VirtualDom_doc.title;
  let bodyNode = __VirtualDom_doc.body;
  let currNode = __VirtualDom_virtualize(bodyNode);

  const onUrlChange = impl.__$onUrlChange;
  const onUrlRequest = impl.__$onUrlRequest;
  const key = _Browser_getKey(onUrlChange)(runtime);

  const setup = () => {
    _Browser_window.addEventListener("popstate", key);
    if (!_Browser_window.navigator.userAgent.includes("Trident")) {
      _Browser_window.addEventListener("hashchange", key);
    }

    return F2(function (domNode, event) {
      if (
        !event.ctrlKey &&
        !event.metaKey &&
        !event.shiftKey &&
        event.button < 1 &&
        !domNode.target &&
        !domNode.hasAttribute("download")
      ) {
        event.preventDefault();
        const href = domNode.href;
        const curr = _Browser_getUrl();
        const next = __Url_fromString(href).a;
        eventNode(
          onUrlRequest(
            next &&
              curr.__$protocol === next.__$protocol &&
              curr.__$host === next.__$host &&
              curr.__$port_.a === next.__$port_.a
              ? __Browser_Internal(next)
              : __Browser_External(href)
          )
        );
      }
    });
  };

  const divertHrefToApp = setup();
  return _Browser_makeAnimator(initialModel, function (model) {
    __VirtualDom_divertHrefToApp = divertHrefToApp;
    const doc = impl.view(model);
    const nextNode = __VirtualDom_node("body")(__List_Nil)(doc.__$body);
    const patches = __VirtualDom_diff(currNode, nextNode);
    bodyNode = __VirtualDom_applyPatches(bodyNode, currNode, patches, eventNode);
    currNode = nextNode;
    __VirtualDom_divertHrefToApp = 0;
    if (title !== doc.__$title) {
      __VirtualDom_doc.title = doc.__$title;
      title = doc.__$title;
    }
  });
};

function _Browser_getUrl() {
  return __Url_fromString(__VirtualDom_doc.location.href).a || __Debug_crash(1);
}

const _Browser_getKey = (onUrlChange) => (runtime) => {
  const eventNode = __Platform_browserifiedSendToApp(runtime);
  return () => eventNode(onUrlChange(_Browser_getUrl()));
};

const _Browser_go = (key) => (n) => {
  if (n !== 0) {
    history.go(n);
  }

  key();
  return __Utils_Tuple0;
};

const _Browser_pushUrl = (key) => (url) => {
  history.pushState({}, "", url);
  key();
  return __Utils_Tuple0;
};

const _Browser_replaceUrl = (key) => (url) => {
  history.replaceState({}, "", url);
  key();
  return __Utils_Tuple0;
};

// GLOBAL EVENTS

const _Browser_fakeNode = { addEventListener() {}, removeEventListener() {} };
const _Browser_doc = typeof document !== "undefined" ? document : _Browser_fakeNode;
var _Browser_window = typeof window !== "undefined" ? window : _Browser_fakeNode;

const _Browser_on = F3(function (node, eventName, onEvent) {
  function handler(event) {
    onEvent(event);
  }

  node.addEventListener(eventName, handler, __VirtualDom_passiveSupported && { passive: true });
  return {
    __eventName: eventName,
    __node: node,
    __handler: handler,
  };
});

const _Browser_off = (effectId) => {
  effectId.__node.removeEventListener(effectId.__eventName, effectId.__handler);
  return __Utils_Tuple0;
};

const _Browser_decodeEvent = F2(function (decoder, event) {
  const result = __Json_runHelp(decoder, event);
  return __Result_isOk(result) ? __Maybe_Just(result.a) : __Maybe_Nothing;
});

// PAGE VISIBILITY

function _Browser_visibilityInfo() {
  return typeof __VirtualDom_doc.hidden !== "undefined"
    ? { __$hidden: "hidden", __$change: "visibilitychange" }
    : typeof __VirtualDom_doc.mozHidden !== "undefined"
    ? { __$hidden: "mozHidden", __$change: "mozvisibilitychange" }
    : typeof __VirtualDom_doc.msHidden !== "undefined"
    ? { __$hidden: "msHidden", __$change: "msvisibilitychange" }
    : typeof __VirtualDom_doc.webkitHidden !== "undefined"
    ? { __$hidden: "webkitHidden", __$change: "webkitvisibilitychange" }
    : { __$hidden: "hidden", __$change: "visibilitychange" };
}

// ANIMATION FRAMES

function _Browser_rawRaf(cb) {
  let id = requestAnimationFrame(() => cb(Date.now()));

  return function () {
    if (id !== null) {
      cancelAnimationFrame(id);
    }

    id = null;
    return __Utils_Tuple0;
  };
}

function _Browser_animationFrameOn(cb) {
  let time = Date.now();
  const onFrame = () => {
    id = requestAnimationFrame(onFrame);
    const oldTime = time;
    time = Date.now();
    const delta = time - oldTime;

    cb({
      __$now: time,
      __$delta: delta,
    });
  };

  let id = requestAnimationFrame(onFrame);

  return id;
}

function _Browser_animationFrameOff(cb) {
  cancelAnimationFrame(id);
}

// DOM STUFF

const _Browser_getNode = (id) => {
  const node = document.getElementById(id);
  return node === null ? __Maybe_Nothing : __Maybe_Just(node);
};

// FOCUS and BLUR

const _Browser_blur = (node) => {
  node.blur();
  return __Utils_Tuple0;
};

const _Browser_focus = (node) => {
  node.focus();
  return __Utils_Tuple0;
};

// WINDOW VIEWPORT

function _Browser_getViewport() {
  return {
    __$scene: _Browser_getScene(),
    __$viewport: {
      __$x: _Browser_window.pageXOffset,
      __$y: _Browser_window.pageYOffset,
      __$width: _Browser_doc.documentElement.clientWidth,
      __$height: _Browser_doc.documentElement.clientHeight,
    },
  };
}

function _Browser_getScene() {
  const body = _Browser_doc.body;
  const element = _Browser_doc.documentElement;
  return {
    __$width: Math.max(
      body.scrollWidth,
      body.offsetWidth,
      element.scrollWidth,
      element.offsetWidth,
      element.clientWidth
    ),
    __$height: Math.max(
      body.scrollHeight,
      body.offsetHeight,
      element.scrollHeight,
      element.offsetHeight,
      element.clientHeight
    ),
  };
}

const _Browser_setViewport = (x) => (y) => _Browser_window.scroll(x, y);

// ELEMENT VIEWPORT

function _Browser_getViewportOf(id) {
  return _Browser_withNode(id, function (node) {
    return {
      __$scene: {
        __$width: node.scrollWidth,
        __$height: node.scrollHeight,
      },
      __$viewport: {
        __$x: node.scrollLeft,
        __$y: node.scrollTop,
        __$width: node.clientWidth,
        __$height: node.clientHeight,
      },
    };
  });
}

const _Browser_setViewportOf = (node) => (x) => (y) => {
  node.scrollLeft = x;
  node.scrollTop = y;
  return __Utils_Tuple0;
};

// ELEMENT

function _Browser_getElement(node) {
  const rect = node.getBoundingClientRect();
  const x = _Browser_window.pageXOffset;
  const y = _Browser_window.pageYOffset;
  return {
    __$scene: _Browser_getScene(),
    __$viewport: {
      __$x: x,
      __$y: y,
      __$width: _Browser_doc.documentElement.clientWidth,
      __$height: _Browser_doc.documentElement.clientHeight,
    },
    __$element: {
      __$x: x + rect.left,
      __$y: y + rect.top,
      __$width: rect.width,
      __$height: rect.height,
    },
  };
}

// LOAD and RELOAD

function _Browser_reload(skipCache) {
  __VirtualDom_doc.location.reload(skipCache);
}

function _Browser_load(url) {
  try {
    _Browser_window.location = url;
  } catch (error) {
    // Only Firefox can throw a NS_ERROR_MALFORMED_URI exception here.
    // Other browsers reload the page, so let's be consistent about that.
    __VirtualDom_doc.location.reload(false);
  }
}

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Browser_.*" }] */

/* global __Basics_never */
/* global __Browser_Internal, __Browser_External */
/* global __Dom_NotFound */
/* global __Debug_crash */
/* global __Json_runHelp */
/* global __List_Nil */
/* global __Platform_initialize, __Platform_browserifiedSendToApp */
/* global __Utils_Tuple0, __Utils_Tuple2 */
/* global __VirtualDom_appendChild, __VirtualDom_applyPatches, __VirtualDom_diff, __VirtualDom_doc, __VirtualDom_node, __VirtualDom_passiveSupported, __VirtualDom_render, __VirtualDom_divertHrefToApp, __VirtualDom_virtualize */
/* global __Json_map */
/* global __Maybe_Just, __Maybe_Nothing */
/* global __Result_isOk */
/* global __Task_perform, __Task_succeed, __Task_fail */
/* global __Process_spawn */
/* global __Url_fromString */
