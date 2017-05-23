/*

import Elm.Kernel.Json exposing (run)
import Elm.Kernel.Utils exposing (Tuple0, Tuple2)
import Platform.Cmd as Cmd exposing (none)
import Platform.Sub as Sub exposing (none)

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

function _VirtualDom_node(tag)
{
	return F2(function(factList, kidList) {
		var output = _VirtualDom_openTag(tag, factList);

		var kids = kidList;
		while (kids.ctor !== '[]')
		{
			output += kids._0;
			kids = kids._1;
		}

		return output + '</' + tag + '>';
	});
}


// KEYED NODES

function _VirtualDom_keyedNode(tag)
{
	return F2(function(factList, kidList)
	{
		var output = _VirtualDom_openTag(tag, factList);

		var kids = kidList;
		while (kids.ctor !== '[]')
		{
			output += kids._0._1;
			kids = kids._1;
		}

		return output + '</' + tag + '>';
	});
}


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


// FACTS

function _VirtualDom_openTag(tag, facts)
{
	var output = '<' + tag;
	var styles = ' style="';
	while (facts.ctor !== '[]')
	{
		var fact = facts._0;
		if (fact instanceof String)
		{
			styles += fact;
		}
		else
		{
			output += fact;
		}
		facts = facts._1;
	}

	return (styles.length > 8
		? output + styles + '">'
		: output + '>'
	);
}

var _VirtualDom_mapProperty = F2(function(func, property)
{
	return property;
});


// EVENTS

var _VirtualDom_on = F3(function(name, options, decoder)
{
	return '';
});

var _VirtualDom_map = F2(function(tagger, node)
{
	return node;
});


// STYLE

function _VirtualDom_style(styleList)
{
	var temp = styleList;
	var styles = '';
	while (temp.ctor !== '[]')
	{
		var style = temp._0;
		styles += style._0 + ':' + style._1 + ';'
		temp = temp._1;
	}
	return new String(styles);
}


// ATTRIBUTES

var _VirtualDom_attribute = F2(function(key, value)
{
	return ' ' + key + '="' + value + '"';
});


var _VirtualDom_attributeNS = F3(function(namespace, key, value)
{
	return ' ' + key + '="' + value + '"';
});



// PROPERTIES

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
			var model = impl.init._0;
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
				if (result.ctor === 'Ok')
				{
					var model = impl.init(result._0)._0;
					return impl.view(model);
				}

				throw new Error(
					'Trying to initialize the `' + moduleName + '` module with an unexpected flag.\n'
					+ 'I tried to convert it to an Elm value, but ran into this problem:\n\n'
					+ result._0
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
