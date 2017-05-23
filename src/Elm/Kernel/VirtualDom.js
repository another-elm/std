/*

import Elm.Kernel.Error exposing (throw)
import Elm.Kernel.Json exposing (equality, run)
import Elm.Kernel.List exposing (Cons, Nil)
import Elm.Kernel.Platform exposing (initialize)
import Elm.Kernel.Utils exposing (Tuple0, Tuple2)
import Json.Decode as Json exposing (map)
import Platform.Cmd as Cmd exposing (none)
import Platform.Sub as Sub exposing (none)

*/


var elm_lang$virtual_dom$VirtualDom_Debug$wrap;
var elm_lang$virtual_dom$VirtualDom_Debug$wrapWithFlags;


var _VirtualDom_doc = typeof document !== 'undefined' ? document : {};


////////////  VIRTUAL DOM NODES  ////////////


function _VirtualDom_text(string)
{
	return {
		type: __2_TEXT,
		text: string
	};
}


function _VirtualDom_node(tag)
{
	return F2(function(factList, kidList) {
		return _VirtualDom_nodeHelp(tag, factList, kidList);
	});
}


function _VirtualDom_nodeHelp(tag, factList, kidList)
{
	var organized = _VirtualDom_organizeFacts(factList);
	var namespace = organized.namespace;
	var facts = organized.facts;

	var children = [];
	var descendantsCount = 0;
	while (kidList.ctor !== '[]')
	{
		var kid = kidList._0;
		descendantsCount += (kid.descendantsCount || 0);
		children.push(kid);
		kidList = kidList._1;
	}
	descendantsCount += children.length;

	return {
		type: __2_NODE,
		tag: tag,
		facts: facts,
		children: children,
		namespace: namespace,
		descendantsCount: descendantsCount
	};
}


var _VirtualDom_keyedNode = F3(function(tag, factList, kidList)
{
	var organized = _VirtualDom_organizeFacts(factList);
	var namespace = organized.namespace;
	var facts = organized.facts;

	var children = [];
	var descendantsCount = 0;
	while (kidList.ctor !== '[]')
	{
		var kid = kidList._0;
		descendantsCount += (kid._1.descendantsCount || 0);
		children.push(kid);
		kidList = kidList._1;
	}
	descendantsCount += children.length;

	return {
		type: __2_KEYED_NODE,
		tag: tag,
		facts: facts,
		children: children,
		namespace: namespace,
		descendantsCount: descendantsCount
	};
});


var _VirtualDom_custom = F3(function(factList, model, impl)
{
	var facts = _VirtualDom_organizeFacts(factList).facts;

	return {
		type: __2_CUSTOM,
		facts: facts,
		model: model,
		impl: impl
	};
});


var _VirtualDom_map = F2(function(tagger, node)
{
	return {
		type: __2_TAGGER,
		tagger: tagger,
		node: node,
		descendantsCount: 1 + (node.descendantsCount || 0)
	};
});


function _VirtualDom_thunk(func, args, thunk)
{
	return {
		type: __2_THUNK,
		func: func,
		args: args,
		thunk: thunk,
		node: undefined
	};
}

var _VirtualDom_lazy = F2(function(fn, a)
{
	return _VirtualDom_thunk(fn, [a], function() {
		return fn(a);
	});
});

var _VirtualDom_lazy2 = F3(function(fn, a, b)
{
	return _VirtualDom_thunk(fn, [a,b], function() {
		return A2(fn, a, b);
	});
});

var _VirtualDom_lazy3 = F4(function(fn, a, b, c)
{
	return _VirtualDom_thunk(fn, [a,b,c], function() {
		return A3(fn, a, b, c);
	});
});



// FACTS


function _VirtualDom_organizeFacts(factList)
{
	var namespace, facts = {};

	while (factList.ctor !== '[]')
	{
		var entry = factList._0;
		var key = entry.key;

		if (key === __1_ATTR || key === __1_ATTR_NS || key === __1_EVENT)
		{
			var subFacts = facts[key] || {};
			subFacts[entry.realKey] = entry.value;
			facts[key] = subFacts;
		}
		else if (key === __1_STYLE)
		{
			var styles = facts[key] || {};
			var styleList = entry.value;
			while (styleList.ctor !== '[]')
			{
				var style = styleList._0;
				styles[style._0] = style._1;
				styleList = styleList._1;
			}
			facts[key] = styles;
		}
		else if (key === 'namespace')
		{
			namespace = entry.value;
		}
		else if (key === 'className')
		{
			var classes = facts[key];
			facts[key] = typeof classes === 'undefined'
				? entry.value
				: classes + ' ' + entry.value;
		}
 		else
		{
			facts[key] = entry.value;
		}
		factList = factList._1;
	}

	return {
		facts: facts,
		namespace: namespace
	};
}



////////////  PROPERTIES AND ATTRIBUTES  ////////////


function _VirtualDom_style(value)
{
	return {
		key: __1_STYLE,
		value: value
	};
}


var _VirtualDom_property = F2(function(key, value)
{
	return {
		key: key,
		value: value
	};
});


var _VirtualDom_attribute = F2(function(key, value)
{
	return {
		key: __1_ATTR,
		realKey: key,
		value: value
	};
});


var _VirtualDom_attributeNS = F3(function(namespace, key, value)
{
	return {
		key: __1_ATTR_NS,
		realKey: key,
		value: {
			value: value,
			namespace: namespace
		}
	};
});


var _VirtualDom_on = F3(function(name, options, decoder)
{
	return {
		key: __1_EVENT,
		realKey: name,
		value: {
			options: options,
			decoder: decoder
		}
	};
});


function _VirtualDom_equalEvents(a, b)
{
	if (a.options !== b.options)
	{
		if (a.options.stopPropagation !== b.options.stopPropagation || a.options.preventDefault !== b.options.preventDefault)
		{
			return false;
		}
	}
	return __Json_equality(a.decoder, b.decoder);
}


var _VirtualDom_mapProperty = F2(function(func, property)
{
	if (property.key !== __1_EVENT)
	{
		return property;
	}
	return on(
		property.realKey,
		property.value.options,
		A2(__Json_map, func, property.value.decoder)
	);
});


////////////  RENDER  ////////////


function _VirtualDom_render(vNode, eventNode)
{
	switch (vNode.type)
	{
		case __2_THUNK:
			if (!vNode.node)
			{
				vNode.node = vNode.thunk();
			}
			return _VirtualDom_render(vNode.node, eventNode);

		case __2_TAGGER:
			var subNode = vNode.node;
			var tagger = vNode.tagger;

			while (subNode.type === __2_TAGGER)
			{
				typeof tagger !== 'object'
					? tagger = [tagger, subNode.tagger]
					: tagger.push(subNode.tagger);

				subNode = subNode.node;
			}

			var subEventRoot = { tagger: tagger, parent: eventNode };
			var domNode = _VirtualDom_render(subNode, subEventRoot);
			domNode.elm_event_node_ref = subEventRoot;
			return domNode;

		case __2_TEXT:
			return _VirtualDom_doc.createTextNode(vNode.text);

		case __2_NODE:
			var domNode = vNode.namespace
				? _VirtualDom_doc.createElementNS(vNode.namespace, vNode.tag)
				: _VirtualDom_doc.createElement(vNode.tag);

			_VirtualDom_applyFacts(domNode, eventNode, vNode.facts);

			var children = vNode.children;

			for (var i = 0; i < children.length; i++)
			{
				domNode.appendChild(_VirtualDom_render(children[i], eventNode));
			}

			return domNode;

		case __2_KEYED_NODE:
			var domNode = vNode.namespace
				? _VirtualDom_doc.createElementNS(vNode.namespace, vNode.tag)
				: _VirtualDom_doc.createElement(vNode.tag);

			_VirtualDom_applyFacts(domNode, eventNode, vNode.facts);

			var children = vNode.children;

			for (var i = 0; i < children.length; i++)
			{
				domNode.appendChild(_VirtualDom_render(children[i]._1, eventNode));
			}

			return domNode;

		case __2_CUSTOM:
			var domNode = vNode.impl.render(vNode.model);
			_VirtualDom_applyFacts(domNode, eventNode, vNode.facts);
			return domNode;
	}
}



////////////  APPLY FACTS  ////////////


function _VirtualDom_applyFacts(domNode, eventNode, facts)
{
	for (var key in facts)
	{
		var value = facts[key];

		switch (key)
		{
			case __1_STYLE:
				_VirtualDom_applyStyles(domNode, value);
				break;

			case __1_EVENT:
				_VirtualDom_applyEvents(domNode, eventNode, value);
				break;

			case __1_ATTR:
				_VirtualDom_applyAttrs(domNode, value);
				break;

			case __1_ATTR_NS:
				_VirtualDom_applyAttrsNS(domNode, value);
				break;

			case 'value':
				if (domNode[key] !== value)
				{
					domNode[key] = value;
				}
				break;

			default:
				domNode[key] = value;
				break;
		}
	}
}

function _VirtualDom_applyStyles(domNode, styles)
{
	var domNodeStyle = domNode.style;

	for (var key in styles)
	{
		domNodeStyle[key] = styles[key];
	}
}

function _VirtualDom_applyEvents(domNode, eventNode, events)
{
	var allHandlers = domNode.elm_handlers || {};

	for (var key in events)
	{
		var handler = allHandlers[key];
		var value = events[key];

		if (typeof value === 'undefined')
		{
			domNode.removeEventListener(key, handler);
			allHandlers[key] = undefined;
		}
		else if (typeof handler === 'undefined')
		{
			var handler = _VirtualDom_makeEventHandler(eventNode, value);
			domNode.addEventListener(key, handler);
			allHandlers[key] = handler;
		}
		else
		{
			handler.info = value;
		}
	}

	domNode.elm_handlers = allHandlers;
}

function _VirtualDom_makeEventHandler(eventNode, info)
{
	function eventHandler(event)
	{
		var info = eventHandler.info;

		var value = A2(__Json_run, info.decoder, event);

		if (value.ctor === 'Ok')
		{
			var options = info.options;
			if (options.stopPropagation)
			{
				event.stopPropagation();
			}
			if (options.preventDefault)
			{
				event.preventDefault();
			}

			var message = value._0;

			var currentEventNode = eventNode;
			while (currentEventNode)
			{
				var tagger = currentEventNode.tagger;
				if (typeof tagger === 'function')
				{
					message = tagger(message);
				}
				else
				{
					for (var i = tagger.length; i--; )
					{
						message = tagger[i](message);
					}
				}
				currentEventNode = currentEventNode.parent;
			}
		}
	};

	eventHandler.info = info;

	return eventHandler;
}

function _VirtualDom_applyAttrs(domNode, attrs)
{
	for (var key in attrs)
	{
		var value = attrs[key];
		if (typeof value === 'undefined')
		{
			domNode.removeAttribute(key);
		}
		else
		{
			domNode.setAttribute(key, value);
		}
	}
}

function _VirtualDom_applyAttrsNS(domNode, nsAttrs)
{
	for (var key in nsAttrs)
	{
		var pair = nsAttrs[key];
		var namespace = pair.namespace;
		var value = pair.value;

		if (typeof value === 'undefined')
		{
			domNode.removeAttributeNS(namespace, key);
		}
		else
		{
			domNode.setAttributeNS(namespace, key, value);
		}
	}
}



////////////  DIFF  ////////////


function _VirtualDom_diff(a, b)
{
	var patches = [];
	_VirtualDom_diffHelp(a, b, patches, 0);
	return patches;
}


function _VirtualDom_makePatch(type, index, data)
{
	return {
		index: index,
		type: type,
		data: data,
		domNode: undefined,
		eventNode: undefined
	};
}


function _VirtualDom_diffHelp(a, b, patches, index)
{
	if (a === b)
	{
		return;
	}

	var aType = a.type;
	var bType = b.type;

	// Bail if you run into different types of nodes. Implies that the
	// structure has changed significantly and it's not worth a diff.
	if (aType !== bType)
	{
		patches.push(_VirtualDom_makePatch(__3_REDRAW, index, b));
		return;
	}

	// Now we know that both nodes are the same type.
	switch (bType)
	{
		case __2_THUNK:
			var aArgs = a.args;
			var bArgs = b.args;
			var i = aArgs.length;
			var same = a.func === b.func && i === bArgs.length;
			while (same && i--)
			{
				same = aArgs[i] === bArgs[i];
			}
			if (same)
			{
				b.node = a.node;
				return;
			}
			b.node = b.thunk();
			var subPatches = [];
			_VirtualDom_diffHelp(a.node, b.node, subPatches, 0);
			if (subPatches.length > 0)
			{
				patches.push(_VirtualDom_makePatch(__3_THUNK, index, subPatches));
			}
			return;

		case __2_TAGGER:
			// gather nested taggers
			var aTaggers = a.tagger;
			var bTaggers = b.tagger;
			var nesting = false;

			var aSubNode = a.node;
			while (aSubNode.type === __2_TAGGER)
			{
				nesting = true;

				typeof aTaggers !== 'object'
					? aTaggers = [aTaggers, aSubNode.tagger]
					: aTaggers.push(aSubNode.tagger);

				aSubNode = aSubNode.node;
			}

			var bSubNode = b.node;
			while (bSubNode.type === __2_TAGGER)
			{
				nesting = true;

				typeof bTaggers !== 'object'
					? bTaggers = [bTaggers, bSubNode.tagger]
					: bTaggers.push(bSubNode.tagger);

				bSubNode = bSubNode.node;
			}

			// Just bail if different numbers of taggers. This implies the
			// structure of the virtual DOM has changed.
			if (nesting && aTaggers.length !== bTaggers.length)
			{
				patches.push(_VirtualDom_makePatch(__3_REDRAW, index, b));
				return;
			}

			// check if taggers are "the same"
			if (nesting ? !_VirtualDom_pairwiseRefEqual(aTaggers, bTaggers) : aTaggers !== bTaggers)
			{
				patches.push(_VirtualDom_makePatch(__3_TAGGER, index, bTaggers));
			}

			// diff everything below the taggers
			_VirtualDom_diffHelp(aSubNode, bSubNode, patches, index + 1);
			return;

		case __2_TEXT:
			if (a.text !== b.text)
			{
				patches.push(_VirtualDom_makePatch(__3_TEXT, index, b.text));
				return;
			}

			return;

		case __2_NODE:
			// Bail if obvious indicators have changed. Implies more serious
			// structural changes such that it's not worth it to diff.
			if (a.tag !== b.tag || a.namespace !== b.namespace)
			{
				patches.push(_VirtualDom_makePatch(__3_REDRAW, index, b));
				return;
			}

			var factsDiff = _VirtualDom_diffFacts(a.facts, b.facts);

			if (typeof factsDiff !== 'undefined')
			{
				patches.push(_VirtualDom_makePatch(__3_FACTS, index, factsDiff));
			}

			_VirtualDom_diffChildren(a, b, patches, index);
			return;

		case __2_KEYED_NODE:
			// Bail if obvious indicators have changed. Implies more serious
			// structural changes such that it's not worth it to diff.
			if (a.tag !== b.tag || a.namespace !== b.namespace)
			{
				patches.push(_VirtualDom_makePatch(__3_REDRAW, index, b));
				return;
			}

			var factsDiff = _VirtualDom_diffFacts(a.facts, b.facts);

			if (typeof factsDiff !== 'undefined')
			{
				patches.push(_VirtualDom_makePatch(__3_FACTS, index, factsDiff));
			}

			_VirtualDom_diffKeyedChildren(a, b, patches, index);
			return;

		case __2_CUSTOM:
			if (a.impl !== b.impl)
			{
				patches.push(_VirtualDom_makePatch(__3_REDRAW, index, b));
				return;
			}

			var factsDiff = _VirtualDom_diffFacts(a.facts, b.facts);
			if (typeof factsDiff !== 'undefined')
			{
				patches.push(_VirtualDom_makePatch(__3_FACTS, index, factsDiff));
			}

			var patch = b.impl.diff(a,b);
			if (patch)
			{
				patches.push(_VirtualDom_makePatch(__3_CUSTOM, index, patch));
				return;
			}

			return;
	}
}


// assumes the incoming arrays are the same length
function _VirtualDom_pairwiseRefEqual(as, bs)
{
	for (var i = 0; i < as.length; i++)
	{
		if (as[i] !== bs[i])
		{
			return false;
		}
	}

	return true;
}


// TODO Instead of creating a new diff object, it's possible to just test if
// there *is* a diff. During the actual patch, do the diff again and make the
// modifications directly. This way, there's no new allocations. Worth it?
function _VirtualDom_diffFacts(a, b, category)
{
	var diff;

	// look for changes and removals
	for (var aKey in a)
	{
		if (aKey === __1_STYLE || aKey === __1_EVENT || aKey === __1_ATTR || aKey === __1_ATTR_NS)
		{
			var subDiff = _VirtualDom_diffFacts(a[aKey], b[aKey] || {}, aKey);
			if (subDiff)
			{
				diff = diff || {};
				diff[aKey] = subDiff;
			}
			continue;
		}

		// remove if not in the new facts
		if (!(aKey in b))
		{
			diff = diff || {};
			diff[aKey] =
				(typeof category === 'undefined')
					? (typeof a[aKey] === 'string' ? '' : null)
					:
				(category === __1_STYLE)
					? ''
					:
				(category === __1_EVENT || category === __1_ATTR)
					? undefined
					:
				{ namespace: a[aKey].namespace, value: undefined };

			continue;
		}

		var aValue = a[aKey];
		var bValue = b[aKey];

		// reference equal, so don't worry about it
		if (aValue === bValue && aKey !== 'value'
			|| category === __1_EVENT && _VirtualDom_equalEvents(aValue, bValue))
		{
			continue;
		}

		diff = diff || {};
		diff[aKey] = bValue;
	}

	// add new stuff
	for (var bKey in b)
	{
		if (!(bKey in a))
		{
			diff = diff || {};
			diff[bKey] = b[bKey];
		}
	}

	return diff;
}


function _VirtualDom_diffChildren(aParent, bParent, patches, rootIndex)
{
	var aChildren = aParent.children;
	var bChildren = bParent.children;

	var aLen = aChildren.length;
	var bLen = bChildren.length;

	// FIGURE OUT IF THERE ARE INSERTS OR REMOVALS

	if (aLen > bLen)
	{
		patches.push(_VirtualDom_makePatch(__3_REMOVE_LAST, rootIndex, aLen - bLen));
	}
	else if (aLen < bLen)
	{
		patches.push(_VirtualDom_makePatch(__3_APPEND, rootIndex, bChildren.slice(aLen)));
	}

	// PAIRWISE DIFF EVERYTHING ELSE

	var index = rootIndex;
	var minLen = aLen < bLen ? aLen : bLen;
	for (var i = 0; i < minLen; i++)
	{
		index++;
		var aChild = aChildren[i];
		_VirtualDom_diffHelp(aChild, bChildren[i], patches, index);
		index += aChild.descendantsCount || 0;
	}
}



////////////  KEYED DIFF  ////////////


function _VirtualDom_diffKeyedChildren(aParent, bParent, patches, rootIndex)
{
	var localPatches = [];

	var changes = {}; // Dict String Entry
	var inserts = []; // Array { index : Int, entry : Entry }
	// type Entry = { tag : String, vnode : VNode, index : Int, data : _ }

	var aChildren = aParent.children;
	var bChildren = bParent.children;
	var aLen = aChildren.length;
	var bLen = bChildren.length;
	var aIndex = 0;
	var bIndex = 0;

	var index = rootIndex;

	while (aIndex < aLen && bIndex < bLen)
	{
		var a = aChildren[aIndex];
		var b = bChildren[bIndex];

		var aKey = a._0;
		var bKey = b._0;
		var aNode = a._1;
		var bNode = b._1;

		// check if keys match

		if (aKey === bKey)
		{
			index++;
			_VirtualDom_diffHelp(aNode, bNode, localPatches, index);
			index += aNode.descendantsCount || 0;

			aIndex++;
			bIndex++;
			continue;
		}

		// look ahead 1 to detect insertions and removals.

		var aLookAhead = aIndex + 1 < aLen;
		var bLookAhead = bIndex + 1 < bLen;

		if (aLookAhead)
		{
			var aNext = aChildren[aIndex + 1];
			var aNextKey = aNext._0;
			var aNextNode = aNext._1;
			var oldMatch = bKey === aNextKey;
		}

		if (bLookAhead)
		{
			var bNext = bChildren[bIndex + 1];
			var bNextKey = bNext._0;
			var bNextNode = bNext._1;
			var newMatch = aKey === bNextKey;
		}


		// swap a and b
		if (aLookAhead && bLookAhead && newMatch && oldMatch)
		{
			index++;
			_VirtualDom_diffHelp(aNode, bNextNode, localPatches, index);
			_VirtualDom_insertNode(changes, localPatches, aKey, bNode, bIndex, inserts);
			index += aNode.descendantsCount || 0;

			index++;
			_VirtualDom_removeNode(changes, localPatches, aKey, aNextNode, index);
			index += aNextNode.descendantsCount || 0;

			aIndex += 2;
			bIndex += 2;
			continue;
		}

		// insert b
		if (bLookAhead && newMatch)
		{
			index++;
			_VirtualDom_insertNode(changes, localPatches, bKey, bNode, bIndex, inserts);
			_VirtualDom_diffHelp(aNode, bNextNode, localPatches, index);
			index += aNode.descendantsCount || 0;

			aIndex += 1;
			bIndex += 2;
			continue;
		}

		// remove a
		if (aLookAhead && oldMatch)
		{
			index++;
			_VirtualDom_removeNode(changes, localPatches, aKey, aNode, index);
			index += aNode.descendantsCount || 0;

			index++;
			_VirtualDom_diffHelp(aNextNode, bNode, localPatches, index);
			index += aNextNode.descendantsCount || 0;

			aIndex += 2;
			bIndex += 1;
			continue;
		}

		// remove a, insert b
		if (aLookAhead && bLookAhead && aNextKey === bNextKey)
		{
			index++;
			_VirtualDom_removeNode(changes, localPatches, aKey, aNode, index);
			_VirtualDom_insertNode(changes, localPatches, bKey, bNode, bIndex, inserts);
			index += aNode.descendantsCount || 0;

			index++;
			_VirtualDom_diffHelp(aNextNode, bNextNode, localPatches, index);
			index += aNextNode.descendantsCount || 0;

			aIndex += 2;
			bIndex += 2;
			continue;
		}

		break;
	}

	// eat up any remaining nodes with removeNode and insertNode

	while (aIndex < aLen)
	{
		index++;
		var a = aChildren[aIndex];
		var aNode = a._1;
		_VirtualDom_removeNode(changes, localPatches, a._0, aNode, index);
		index += aNode.descendantsCount || 0;
		aIndex++;
	}

	var endInserts;
	while (bIndex < bLen)
	{
		endInserts = endInserts || [];
		var b = bChildren[bIndex];
		_VirtualDom_insertNode(changes, localPatches, b._0, b._1, undefined, endInserts);
		bIndex++;
	}

	if (localPatches.length > 0 || inserts.length > 0 || typeof endInserts !== 'undefined')
	{
		patches.push(_VirtualDom_makePatch(__3_REORDER, rootIndex, {
			patches: localPatches,
			inserts: inserts,
			endInserts: endInserts
		}));
	}
}



////////////  CHANGES FROM KEYED DIFF  ////////////


var _VirtualDom_POSTFIX = '_elmW6BL';


function _VirtualDom_insertNode(changes, localPatches, key, vnode, bIndex, inserts)
{
	var entry = changes[key];

	// never seen this key before
	if (typeof entry === 'undefined')
	{
		entry = {
			tag: 'insert',
			vnode: vnode,
			index: bIndex,
			data: undefined
		};

		inserts.push({ index: bIndex, entry: entry });
		changes[key] = entry;

		return;
	}

	// this key was removed earlier, a match!
	if (entry.tag === 'remove')
	{
		inserts.push({ index: bIndex, entry: entry });

		entry.tag = 'move';
		var subPatches = [];
		_VirtualDom_diffHelp(entry.vnode, vnode, subPatches, entry.index);
		entry.index = bIndex;
		entry.data.data = {
			patches: subPatches,
			entry: entry
		};

		return;
	}

	// this key has already been inserted or moved, a duplicate!
	_VirtualDom_insertNode(changes, localPatches, key + _VirtualDom_POSTFIX, vnode, bIndex, inserts);
}


function _VirtualDom_removeNode(changes, localPatches, key, vnode, index)
{
	var entry = changes[key];

	// never seen this key before
	if (typeof entry === 'undefined')
	{
		var patch = _VirtualDom_makePatch(__3_REMOVE, index, undefined);
		localPatches.push(patch);

		changes[key] = {
			tag: 'remove',
			vnode: vnode,
			index: index,
			data: patch
		};

		return;
	}

	// this key was inserted earlier, a match!
	if (entry.tag === 'insert')
	{
		entry.tag = 'move';
		var subPatches = [];
		_VirtualDom_diffHelp(vnode, entry.vnode, subPatches, index);

		var patch = _VirtualDom_makePatch(__3_REMOVE, index, {
			patches: subPatches,
			entry: entry
		});
		localPatches.push(patch);

		return;
	}

	// this key has already been removed or moved, a duplicate!
	_VirtualDom_removeNode(changes, localPatches, key + _VirtualDom_POSTFIX, vnode, index);
}



////////////  ADD DOM NODES  ////////////
//
// Each DOM node has an "index" assigned in order of traversal. It is important
// to minimize our crawl over the actual DOM, so these indexes (along with the
// descendantsCount of virtual nodes) let us skip touching entire subtrees of
// the DOM if we know there are no patches there.


function _VirtualDom_addDomNodes(domNode, vNode, patches, eventNode)
{
	_VirtualDom_addDomNodesHelp(domNode, vNode, patches, 0, 0, vNode.descendantsCount, eventNode);
}


// assumes `patches` is non-empty and indexes increase monotonically.
function _VirtualDom_addDomNodesHelp(domNode, vNode, patches, i, low, high, eventNode)
{
	var patch = patches[i];
	var index = patch.index;

	while (index === low)
	{
		var patchType = patch.type;

		if (patchType === __3_THUNK)
		{
			_VirtualDom_addDomNodes(domNode, vNode.node, patch.data, eventNode);
		}
		else if (patchType === __3_REORDER)
		{
			patch.domNode = domNode;
			patch.eventNode = eventNode;

			var subPatches = patch.data.patches;
			if (subPatches.length > 0)
			{
				_VirtualDom_addDomNodesHelp(domNode, vNode, subPatches, 0, low, high, eventNode);
			}
		}
		else if (patchType === __3_REMOVE)
		{
			patch.domNode = domNode;
			patch.eventNode = eventNode;

			var data = patch.data;
			if (typeof data !== 'undefined')
			{
				data.entry.data = domNode;
				var subPatches = data.patches;
				if (subPatches.length > 0)
				{
					_VirtualDom_addDomNodesHelp(domNode, vNode, subPatches, 0, low, high, eventNode);
				}
			}
		}
		else
		{
			patch.domNode = domNode;
			patch.eventNode = eventNode;
		}

		i++;

		if (!(patch = patches[i]) || (index = patch.index) > high)
		{
			return i;
		}
	}

	switch (vNode.type)
	{
		case __2_TAGGER:
			var subNode = vNode.node;

			while (subNode.type === __2_TAGGER)
			{
				subNode = subNode.node;
			}

			return _VirtualDom_addDomNodesHelp(domNode, subNode, patches, i, low + 1, high, domNode.elm_event_node_ref);

		case __2_NODE:
			var vChildren = vNode.children;
			var childNodes = domNode.childNodes;
			for (var j = 0; j < vChildren.length; j++)
			{
				low++;
				var vChild = vChildren[j];
				var nextLow = low + (vChild.descendantsCount || 0);
				if (low <= index && index <= nextLow)
				{
					i = _VirtualDom_addDomNodesHelp(childNodes[j], vChild, patches, i, low, nextLow, eventNode);
					if (!(patch = patches[i]) || (index = patch.index) > high)
					{
						return i;
					}
				}
				low = nextLow;
			}
			return i;

		case __2_KEYED_NODE:
			var vChildren = vNode.children;
			var childNodes = domNode.childNodes;
			for (var j = 0; j < vChildren.length; j++)
			{
				low++;
				var vChild = vChildren[j]._1;
				var nextLow = low + (vChild.descendantsCount || 0);
				if (low <= index && index <= nextLow)
				{
					i = _VirtualDom_addDomNodesHelp(childNodes[j], vChild, patches, i, low, nextLow, eventNode);
					if (!(patch = patches[i]) || (index = patch.index) > high)
					{
						return i;
					}
				}
				low = nextLow;
			}
			return i;

		case __2_TEXT:
		case __2_THUNK:
			__Error_throw(13); // 'should never traverse `text` or `thunk` nodes like this'
	}
}



////////////  APPLY PATCHES  ////////////


function _VirtualDom_applyPatches(rootDomNode, oldVirtualNode, patches, eventNode)
{
	if (patches.length === 0)
	{
		return rootDomNode;
	}

	_VirtualDom_addDomNodes(rootDomNode, oldVirtualNode, patches, eventNode);
	return _VirtualDom_applyPatchesHelp(rootDomNode, patches);
}

function _VirtualDom_applyPatchesHelp(rootDomNode, patches)
{
	for (var i = 0; i < patches.length; i++)
	{
		var patch = patches[i];
		var localDomNode = patch.domNode
		var newNode = _VirtualDom_applyPatch(localDomNode, patch);
		if (localDomNode === rootDomNode)
		{
			rootDomNode = newNode;
		}
	}
	return rootDomNode;
}

function _VirtualDom_applyPatch(domNode, patch)
{
	switch (patch.type)
	{
		case __3_REDRAW:
			return _VirtualDom_applyPatchRedraw(domNode, patch.data, patch.eventNode);

		case __3_FACTS:
			_VirtualDom_applyFacts(domNode, patch.eventNode, patch.data);
			return domNode;

		case __3_TEXT:
			domNode.replaceData(0, domNode.length, patch.data);
			return domNode;

		case __3_THUNK:
			return _VirtualDom_applyPatchesHelp(domNode, patch.data);

		case __3_TAGGER:
			if (typeof domNode.elm_event_node_ref !== 'undefined')
			{
				domNode.elm_event_node_ref.tagger = patch.data;
			}
			else
			{
				domNode.elm_event_node_ref = { tagger: patch.data, parent: patch.eventNode };
			}
			return domNode;

		case __3_REMOVE_LAST:
			var i = patch.data;
			while (i--)
			{
				domNode.removeChild(domNode.lastChild);
			}
			return domNode;

		case __3_APPEND:
			var newNodes = patch.data;
			for (var i = 0; i < newNodes.length; i++)
			{
				domNode.appendChild(_VirtualDom_render(newNodes[i], patch.eventNode));
			}
			return domNode;

		case __3_REMOVE:
			var data = patch.data;
			if (typeof data === 'undefined')
			{
				domNode.parentNode.removeChild(domNode);
				return domNode;
			}
			var entry = data.entry;
			if (typeof entry.index !== 'undefined')
			{
				domNode.parentNode.removeChild(domNode);
			}
			entry.data = _VirtualDom_applyPatchesHelp(domNode, data.patches);
			return domNode;

		case __3_REORDER:
			return _VirtualDom_applyPatchReorder(domNode, patch);

		case __3_CUSTOM:
			var impl = patch.data;
			return impl.applyPatch(domNode, impl.data);

		default:
			__Error_throw(13); // 'Ran into an unknown patch!'
	}
}


function _VirtualDom_applyPatchRedraw(domNode, vNode, eventNode)
{
	var parentNode = domNode.parentNode;
	var newNode = _VirtualDom_render(vNode, eventNode);

	if (typeof newNode.elm_event_node_ref === 'undefined')
	{
		newNode.elm_event_node_ref = domNode.elm_event_node_ref;
	}

	if (parentNode && newNode !== domNode)
	{
		parentNode.replaceChild(newNode, domNode);
	}
	return newNode;
}


function _VirtualDom_applyPatchReorder(domNode, patch)
{
	var data = patch.data;

	// remove end inserts
	var frag = _VirtualDom_applyPatchReorderEndInsertsHelp(data.endInserts, patch);

	// removals
	domNode = _VirtualDom_applyPatchesHelp(domNode, data.patches);

	// inserts
	var inserts = data.inserts;
	for (var i = 0; i < inserts.length; i++)
	{
		var insert = inserts[i];
		var entry = insert.entry;
		var node = entry.tag === 'move'
			? entry.data
			: _VirtualDom_render(entry.vnode, patch.eventNode);
		domNode.insertBefore(node, domNode.childNodes[insert.index]);
	}

	// add end inserts
	if (typeof frag !== 'undefined')
	{
		domNode.appendChild(frag);
	}

	return domNode;
}


function _VirtualDom_applyPatchReorderEndInsertsHelp(endInserts, patch)
{
	if (typeof endInserts === 'undefined')
	{
		return;
	}

	var frag = _VirtualDom_doc.createDocumentFragment();
	for (var i = 0; i < endInserts.length; i++)
	{
		var insert = endInserts[i];
		var entry = insert.entry;
		frag.appendChild(entry.tag === 'move'
			? entry.data
			: _VirtualDom_render(entry.vnode, patch.eventNode)
		);
	}
	return frag;
}


// PROGRAMS

var _VirtualDom_program = _VirtualDom_makeProgram(_VirtualDom_checkNoFlags);
var _VirtualDom_programWithFlags = _VirtualDom_makeProgram(_VirtualDom_checkYesFlags);

function _VirtualDom_makeProgram(flagChecker)
{
	return F2(function(debugWrap, impl)
	{
		return function(flagDecoder)
		{
			return function(object, moduleName, debugMetadata)
			{
				var checker = flagChecker(flagDecoder, moduleName);
				if (typeof debugMetadata === 'undefined')
				{
					_VirtualDom_setup(impl, object, moduleName, checker);
				}
				else
				{
					_Degug_setup(A2(debugWrap, debugMetadata, impl), object, moduleName, checker);
				}
			};
		};
	});
}

function _VirtualDom_staticProgram(vNode)
{
	var nothing = __Utils_Tuple2( __Utils_Tuple0, __Cmd_none );
	return A2(_VirtualDom_program, elm_lang$virtual_dom$VirtualDom_Debug$wrap, {
		init: nothing,
		view: function() { return vNode; },
		update: F2(function() { return nothing; }),
		subscriptions: function() { return __Sub_none; }
	})();
}


// FLAG CHECKERS

function _VirtualDom_checkNoFlags(flagDecoder, moduleName)
{
	return function(init, flags, domNode)
	{
		if (typeof flags === 'undefined')
		{
			return init;
		}

		__Error_throw(0);
	};
}

function _VirtualDom_checkYesFlags(flagDecoder, moduleName)
{
	return function(init, flags, domNode)
	{
		if (typeof flagDecoder === 'undefined')
		{
			__Error_throw(1);
		}

		var result = A2(__Json_run, flagDecoder, flags);
		if (result.ctor === 'Ok')
		{
			return init(result._0);
		}

		__Error_throw(2);
	};
}


//  NORMAL SETUP

function _VirtualDom_setup(impl, object, moduleName, flagChecker)
{
	object['embed'] = function embed(node, flags)
	{
		while (node.lastChild)
		{
			node.removeChild(node.lastChild);
		}

		return __Platform_initialize(
			flagChecker(impl.init, flags, node),
			impl.update,
			impl.subscriptions,
			_VirtualDom_renderer(node, impl.view)
		);
	};

	object['fullscreen'] = function fullscreen(flags)
	{
		return __Platform_initialize(
			flagChecker(impl.init, flags, document.body),
			impl.update,
			impl.subscriptions,
			_VirtualDom_renderer(document.body, impl.view)
		);
	};
}


// RENDERER

var _VirtualDom_requestAnimationFrame =
	typeof requestAnimationFrame !== 'undefined'
		? requestAnimationFrame
		: function(callback) { setTimeout(callback, 1000 / 60); };

function _VirtualDom_renderer(domNode, view)
{
	return function(tagger)
	{
		var eventNode = { tagger: tagger, parent: undefined };
		var currNode = virtualize(domNode);

		var state = __4_NO_REQUEST;
		var nextModel;

		function updateIfNeeded()
		{
			switch (state)
			{
				case __4_NO_REQUEST:
					__Error_throw(13); // unexpected draw callback

				case __4_PENDING_REQUEST:
					_VirtualDom_requestAnimationFrame(updateIfNeeded);
					state = __4_EXTRA_REQUEST;

					var nextNode = view(nextModel);
					var patches = _VirtualDom_diff(currNode, nextNode);
					domNode = _VirtualDom_applyPatches(domNode, currNode, patches, eventNode);
					currNode = nextNode;

					return;

				case __4_EXTRA_REQUEST:
					state = __4_NO_REQUEST;
					return;
			}
		}

		return function stepper(model)
		{
			if (state === __4_NO_REQUEST)
			{
				_VirtualDom_requestAnimationFrame(updateIfNeeded);
			}
			state = __4_PENDING_REQUEST;
			nextModel = model;
		};
	};
}

function virtualize(node)
{
	// TEXT NODES

	if (node.nodeType === 3)
	{
		return _VirtualDom_text(node.textContent);
	}
	// else is normal NODE


	// ATTRIBUTES

	var keys;
	var attrList = __List_Nil;
	var attrs = node.attributes;
	for (var i = attrs.length; i--; )
	{
		var attr = attrs[i];
		var name = attr.name;
		var value = attr.value;
		name === 'data-k'
			? keys = value.split('|')
			: attrList = __List_Cons( A2(_VirtualDom_attribute, name, value), attrList );
	}

	var tag = node.tagName.toLowerCase();
	var kidList = __List_Nil;
	var kids = node.childNodes;

	// KEYED NODES

	if (keys)
	{
		for (var i = kids.length; i--; )
		{
			kidList = __List_Cons(__Utils_Tuple2(keys[i], virtualize(kids[i])), kidList);
		}
		return A3(_VirtualDom_keyedNode, tag, attrList, kidList);
	}

	// NORMAL NODES

	for (var i = kids.length; i--; )
	{
		kidList = __List_Cons(virtualize(kids[i]), kidList);
	}
	return A3(_VirtualDom_node, tag, attrList, kidList);
}