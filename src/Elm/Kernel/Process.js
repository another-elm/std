/*

import Elm.Kernel.Scheduler exposing (binding, succeed)
import Elm.Kernel.Utils exposing (Tuple0)

*/


var _Process_delay = F3(function (time, value, callback)
{
	var id = setTimeout(function() {
		callback(value);
	}, time);

	return function(x) { clearTimeout(id); return x; };
})
