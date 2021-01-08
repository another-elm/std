/*

import Basics exposing (never)
import Browser exposing (Internal, External)
import Browser.Dom as Dom exposing (NotFound)
import Elm.Kernel.Debug exposing (crash)
import Elm.Kernel.Json exposing (runHelp)
import Elm.Kernel.List exposing (Nil)
import Elm.Kernel.Platform exposing (initialize, browserifiedSendToApp)
import Elm.Kernel.Scheduler exposing (binding)
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


const _Browser_elementStepperBuilder = (view) => (runtime) => args => (initialModel) => () => {
	/**__PROD/
	var domNode = args['node'];
	//*/
	/**__DEBUG/
	var domNode = args && args['node'] ? args['node'] : __Debug_crash(0);
	//*/
	var currNode = __VirtualDom_virtualize(domNode);
	const eventNode = __Platform_browserifiedSendToApp(runtime);

	return _Browser_makeAnimator(initialModel, function(model)
	{
		var nextNode = view(model);
		var patches = __VirtualDom_diff(currNode, nextNode);
		domNode = __VirtualDom_applyPatches(domNode, currNode, patches, eventNode);
		currNode = nextNode;
	});
};

// DOCUMENT


var _Browser_documentStepperBuilder = (view) => (runtime) => args => (initialModel) => () => {
	const eventNode = __Platform_browserifiedSendToApp(runtime);
	var title = __VirtualDom_doc.title;
	var bodyNode = __VirtualDom_doc.body;
	var currNode = __VirtualDom_virtualize(bodyNode);
	return _Browser_makeAnimator(initialModel, function(model)
	{
		__VirtualDom_divertHrefToApp = divertHrefToApp;
		var doc = view(model);
		var nextNode = __VirtualDom_node('body')(__List_Nil)(doc.__$body);
		var patches = __VirtualDom_diff(currNode, nextNode);
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


var _Browser_cancelAnimationFrame =
	typeof cancelAnimationFrame !== 'undefined'
		? cancelAnimationFrame
		: function(id) { clearTimeout(id); };

var _Browser_requestAnimationFrame =
	typeof requestAnimationFrame !== 'undefined'
		? requestAnimationFrame
		: function(callback) { return setTimeout(callback, 1000 / 60); };


function _Browser_makeAnimator(model, draw)
{
	draw(model);

	var state = __4_NO_REQUEST;

	function updateIfNeeded()
	{
		state = state === __4_EXTRA_REQUEST
			? __4_NO_REQUEST
			: ( _Browser_requestAnimationFrame(updateIfNeeded), draw(model), __4_EXTRA_REQUEST );
	}

	return (nextModel) => (isSync) =>	() => {
		model = nextModel;

		isSync
			? ( draw(model),
				state === __4_PENDING_REQUEST && (state = __4_EXTRA_REQUEST)
				)
			: ( state === __4_NO_REQUEST && _Browser_requestAnimationFrame(updateIfNeeded),
				state = __4_PENDING_REQUEST
				);
	};
}



// APPLICATION


const _Browser_applicationStepperBuilder = (impl) => (runtime) => args => (initialModel) => () => {

	const eventNode = __Platform_browserifiedSendToApp(runtime);
	var title = __VirtualDom_doc.title;
	var bodyNode = __VirtualDom_doc.body;
	var currNode = __VirtualDom_virtualize(bodyNode);

	var onUrlChange = impl.__$onUrlChange;
	var onUrlRequest = impl.__$onUrlRequest;
	var key = _Browser_getKey(onUrlChange)(runtime);

	const setup = () => {
		_Browser_window.addEventListener('popstate', key);
		if (_Browser_window.navigator.userAgent.indexOf('Trident') === -1) {
			_Browser_window.addEventListener('hashchange', key);
		}

		return F2(function(domNode, event)
		{
			if (!event.ctrlKey && !event.metaKey && !event.shiftKey && event.button < 1 && !domNode.target && !domNode.hasAttribute('download'))
			{
				event.preventDefault();
				var href = domNode.href;
				var curr = _Browser_getUrl();
				var next = __Url_fromString(href).a;
				eventNode(onUrlRequest(
					(next
						&& curr.__$protocol === next.__$protocol
						&& curr.__$host === next.__$host
						&& curr.__$port_.a === next.__$port_.a
					)
						? __Browser_Internal(next)
						: __Browser_External(href)
				));
			}
		});
	};
	var divertHrefToApp = setup();
	return _Browser_makeAnimator(initialModel, function(model) {
		__VirtualDom_divertHrefToApp = divertHrefToApp;
		var doc = impl.view(model);
		var nextNode = __VirtualDom_node('body')(__List_Nil)(doc.__$body);
		var patches = __VirtualDom_diff(currNode, nextNode);
		bodyNode = __VirtualDom_applyPatches(bodyNode, currNode, patches, eventNode);
		currNode = nextNode;
		__VirtualDom_divertHrefToApp = 0;
		if (title !== doc.__$title) {
			__VirtualDom_doc.title = doc.__$title;
			title = doc.__$title;
		}
	});
}

function _Browser_getUrl()
{
	return __Url_fromString(__VirtualDom_doc.location.href).a || __Debug_crash(1);
}

const _Browser_getKey = (onUrlChange) => (runtime) => {
	const eventNode = __Platform_browserifiedSendToApp(runtime);
	return () => eventNode(onUrlChange(_Browser_getUrl()));
}

var _Browser_go = F2(function(key, n)
{
	return A2(__Task_perform, __Basics_never, __Scheduler_binding(() => () => {
		n && history.go(n);
		key();
	}));
});

const _Browser_pushUrl = key => url => {
	history.pushState({}, '', url);
	key();
};

var _Browser_replaceUrl = F2(function(key, url)
{
	return A2(__Task_perform, __Basics_never, __Scheduler_binding(() => () =>  {
		history.replaceState({}, '', url);
		key();
	}));
});



// GLOBAL EVENTS


var _Browser_fakeNode = { addEventListener: function() {}, removeEventListener: function() {} };
var _Browser_doc = typeof document !== 'undefined' ? document : _Browser_fakeNode;
var _Browser_window = typeof window !== 'undefined' ? window : _Browser_fakeNode;

var _Browser_on = F3(function(node, eventName, sendToSelf)
{
	return __Process_spawn(__Scheduler_binding(() => () =>
	{
		function handler(event)	{ rawSpawn(sendToSelf(event)); }
		node.addEventListener(eventName, handler, __VirtualDom_passiveSupported && { passive: true });
		return function() { node.removeEventListener(eventName, handler); };
	}));
});

var _Browser_decodeEvent = F2(function(decoder, event)
{
	var result = __Json_runHelp(decoder, event);
	return __Result_isOk(result) ? __Maybe_Just(result.a) : __Maybe_Nothing;
});



// PAGE VISIBILITY


function _Browser_visibilityInfo()
{
	return (typeof __VirtualDom_doc.hidden !== 'undefined')
		? { __$hidden: 'hidden', __$change: 'visibilitychange' }
		:
	(typeof __VirtualDom_doc.mozHidden !== 'undefined')
		? { __$hidden: 'mozHidden', __$change: 'mozvisibilitychange' }
		:
	(typeof __VirtualDom_doc.msHidden !== 'undefined')
		? { __$hidden: 'msHidden', __$change: 'msvisibilitychange' }
		:
	(typeof __VirtualDom_doc.webkitHidden !== 'undefined')
		? { __$hidden: 'webkitHidden', __$change: 'webkitvisibilitychange' }
		: { __$hidden: 'hidden', __$change: 'visibilitychange' };
}



// ANIMATION FRAMES


function _Browser_rAF()
{
	return __Scheduler_binding((callback) => () =>
	{
		var id = _Browser_requestAnimationFrame(function() {
			callback(__Task_succeed(Date.now()));
		});

		return function() {
			_Browser_cancelAnimationFrame(id);
		};
	});
}

function _Browser_rawRaf(cb) {
	let id = requestAnimationFrame(() => cb(Date.now()));

	return function() {
		if (id !== null) {
			_Browser_cancelAnimationFrame(id);
		}
		id = null;
		return __Utils_Tuple0;
	};
}


function _Browser_now()
{
	return __Scheduler_binding((callback) => () =>
	{
		callback(__Task_succeed(Date.now()));
	});
}



// DOM STUFF


const _Browser_getNode = id => {
	const node = document.getElementById(id);
	return node === null
		 ? __Maybe_Nothing
		 : __Maybe_Just(node);
}


function _Browser_withWindow(doStuff)
{
	return __Scheduler_binding((callback) => () =>
	{
		_Browser_requestAnimationFrame(function() {
			callback(__Task_succeed(doStuff()));
		});
	});
}


// FOCUS and BLUR



const _Browser_blur = node => {
	node.blur();
	return __Utils_Tuple0;
};

const _Browser_focus = node => {
	node.focus();
	return __Utils_Tuple0;
};



// WINDOW VIEWPORT


function _Browser_getViewport()
{
	return {
		__$scene: _Browser_getScene(),
		__$viewport: {
			__$x: _Browser_window.pageXOffset,
			__$y: _Browser_window.pageYOffset,
			__$width: _Browser_doc.documentElement.clientWidth,
			__$height: _Browser_doc.documentElement.clientHeight
		}
	};
}

function _Browser_getScene()
{
	var body = _Browser_doc.body;
	var elem = _Browser_doc.documentElement;
	return {
		__$width: Math.max(body.scrollWidth, body.offsetWidth, elem.scrollWidth, elem.offsetWidth, elem.clientWidth),
		__$height: Math.max(body.scrollHeight, body.offsetHeight, elem.scrollHeight, elem.offsetHeight, elem.clientHeight)
	};
}

var _Browser_setViewport = x => y => _Browser_window.scroll(x, y);



// ELEMENT VIEWPORT


function _Browser_getViewportOf(id)
{
	return _Browser_withNode(id, function(node)
	{
		return {
			__$scene: {
				__$width: node.scrollWidth,
				__$height: node.scrollHeight
			},
			__$viewport: {
				__$x: node.scrollLeft,
				__$y: node.scrollTop,
				__$width: node.clientWidth,
				__$height: node.clientHeight
			}
		};
	});
}


var _Browser_setViewportOf = node => x => y => {
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
			__$height: _Browser_doc.documentElement.clientHeight
		},
		__$element: {
			__$x: x + rect.left,
			__$y: y + rect.top,
			__$width: rect.width,
			__$height: rect.height
		}
	};
}



// LOAD and RELOAD


function _Browser_reload(skipCache)
{
	return A2(__Task_perform, __Basics_never, __Scheduler_binding((callback) => () =>
	{
		__VirtualDom_doc.location.reload(skipCache);
	}));
}

function _Browser_load(url)
{
	return A2(__Task_perform, __Basics_never, __Scheduler_binding((callback) => () =>
	{
		try
		{
			_Browser_window.location = url;
		}
		catch(err)
		{
			// Only Firefox can throw a NS_ERROR_MALFORMED_URI exception here.
			// Other browsers reload the page, so let's be consistent about that.
			__VirtualDom_doc.location.reload(false);
		}
	}));
}
