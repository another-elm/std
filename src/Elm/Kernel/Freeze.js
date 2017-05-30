/*

import Elm.Kernel.Json exposing (run)

*/


// TEXT

function _VirtualDom_text(string)
{
	return string.replace(badChars, replaceBadChars);
}

var badChars = /[&<>"']/g;

var table = {
	'&': "&amp;",
	'<': "&lt;",
	'>': "&gt;",
	'"': "&quot;",
	"'": "&#039;"
};

function replaceBadChars(m)
{
	return table[m];
}


// NODES

var _VirtualDom_nodeNS = F2(function(namespace, tag)
{
	return F2(function(factList, kidList) {
		var output = _VirtualDom_openTag(tag, factList);

		while (kidList.$ !== '[]')
		{
			output += kidList.a;
			kidList = kidList.b;
		}

		return output + '</' + tag + '>';
	});
});

var _VirtualDom_node = _VirtualDom_nodeNS(undefined);


// KEYED NODES

var _VirtualDom_keyedNodeNS = F2(function(namespace, tag)
{
	return F2(function(factList, kidList)
	{
		var output = _VirtualDom_openTag(tag, factList);

		while (kidList.$ !== '[]')
		{
			output += kidList.a.b;
			kidList = kidList.b;
		}

		return output + '</' + tag + '>';
	});
});

var _VirtualDom_keyedNode = _VirtualDom_keyedNodeNS(undefined);


// CUSTOM

var _VirtualDom_custom = F3(function(factList, model, impl)
{
	return _VirtualDom_openTag('div', factList) + '</div>';
});


// LAZY

var _VirtualDom_lazy = F2(function(fn, a)
{
	return fn(a);
});

var _VirtualDom_lazy2 = F3(function(fn, a, b)
{
	return A2(fn, a, b);
});

var _VirtualDom_lazy3 = F4(function(fn, a, b, c)
{
	return A3(fn, a, b, c);
});


// MAP

var _VirtualDom_map = F2(function(tagger, node)
{
	return node;
});

var _VirtualDom_mapAttribute = F2(function(func, attr)
{
	return attr;
});


// FACTS

function _VirtualDom_openTag(tag, facts)
{
	var output = '<' + tag;
	var styles = ' style="';
	while (facts.$ !== '[]')
	{
		var fact = facts.a;
		if (fact instanceof String)
		{
			styles += fact;
		}
		else
		{
			output += fact;
		}
		facts = facts.b;
	}

	return (styles.length > 8
		? output + styles + '">'
		: output + '>'
	);
}


// FACTS

var _VirtualDom_style = F2(function(key, value)
{
	return new String(key + ':' + value + ';');
});

var _VirtualDom_attribute = F2(function(key, value)
{
	return ' ' + key + '="' + value + '"';
});

var _VirtualDom_attributeNS = F3(function(namespace, key, value)
{
	return '';
});

var _VirtualDom_on = F3(function(useCapture, name, decoder)
{
	return '';
});

var _VirtualDom_property = F2(function(key, value)
{
	return ' ' + (propertyToAttribute[key] || key) + '="' + value + '"';
});

var propertyToAttribute = {
	'className': 'class',
	'htmlFor': 'for',
	'httpEquiv': 'http-equiv',
	'acceptCharset': 'accept-charset'
};



// PROGRAMS

function _VirtualDom_staticProgram(html)
{
	return function(flagDecoder)
	{
		return function(object, moduleName)
		{
			object['freeze'] = function freeze(flags)
			{
				_VirtualDom_checkNoFlags(moduleName, flags);
				return html;
			};
		};
	};
}

var _VirtualDom_program = F2(function(_, impl)
{
	return function(flagDecoder)
	{
		return function(object, moduleName)
		{
			var model = impl.init.a;
			var html = impl.view(model);

			object['freeze'] = function freeze(flags)
			{
				_VirtualDom_checkNoFlags(moduleName, flags);
				return html;
			};
		};
	};
});

var _VirtualDom_programWithFlags = F2(function(_, impl)
{
	return function(flagDecoder)
	{
		return function(object, moduleName)
		{
			object['freeze'] = function freeze(flags)
			{
				var result = A2(__Json_run, flagDecoder, flags);
				if (result.$ === 'Ok')
				{
					var model = impl.init(result.a).a;
					return impl.view(model);
				}

				throw new Error(
					'Trying to initialize the `' + moduleName + '` module with an unexpected flag.\n'
					+ 'I tried to convert it to an Elm value, but ran into this problem:\n\n'
					+ result.a
				);
			};
		};
	};
});


// FLAG CHECKERS

function _VirtualDom_checkNoFlags(moduleName, flags)
{
	if (typeof flags !== 'undefined')
	{
		throw new Error(
			'The `' + moduleName + '` module does not need flags.\n'
			+ 'Initialize it with no arguments and you should be all set!'
		);
	}
}
