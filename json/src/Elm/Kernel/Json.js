/*

import Array exposing (initialize)
import Elm.Kernel.List exposing (Cons, Nil, fromArray)
import Elm.Kernel.Utils exposing (Tuple2)
import Json.Decode as Json exposing (Field, Index, OneOf, Failure, errorToString)
import List exposing (reverse)
import Maybe exposing (Just, Nothing)
import Result exposing (Ok, Err, isOk)

*/

// CORE DECODERS

function _Json_succeed(message) {
  return {
    $: __1_SUCCEED,
    __msg: message,
  };
}

function _Json_fail(message) {
  return {
    $: __1_FAIL,
    __msg: message,
  };
}

function _Json_decodePrim(decoder) {
  return { $: __1_PRIM, __decoder: decoder };
}

const _Json_decodeInt = _Json_decodePrim((value) => {
  return Number.isInteger(value)
    ? __Result_Ok(value)
    : _Json_expecting("an INT", value);
});

const _Json_decodeBool = _Json_decodePrim((value) => {
  return typeof value === "boolean" ? __Result_Ok(value) : _Json_expecting("a BOOL", value);
});

const _Json_decodeFloat = _Json_decodePrim((value) => {
  return typeof value === "number" ? __Result_Ok(value) : _Json_expecting("a FLOAT", value);
});

const _Json_decodeValue = _Json_decodePrim((value) => {
  return __Result_Ok(_Json_wrap(value));
});

const _Json_decodeString = _Json_decodePrim((value) => {
  if (typeof value === "string") {
	  return __Result_Ok(value);
  } else if (value instanceof String) {
    return __Result_Ok(String(value));
  }
  return _Json_expecting("a STRING", value);
});

function _Json_decodeList(decoder) {
  return { $: __1_LIST, __decoder: decoder };
}

function _Json_decodeArray(decoder) {
  return { $: __1_ARRAY, __decoder: decoder };
}

function _Json_decodeNull(value) {
  return { $: __1_NULL, __value: value };
}

const _Json_decodeField = F2((field, decoder) => {
  return {
    $: __1_FIELD,
    __field: field,
    __decoder: decoder,
  };
});

const _Json_decodeIndex = F2((index, decoder) => {
  return {
    $: __1_INDEX,
    __index: index,
    __decoder: decoder,
  };
});

function _Json_decodeKeyValuePairs(decoder) {
  return {
    $: __1_KEY_VALUE,
    __decoder: decoder,
  };
}

function _Json_mapMany(f, decoders) {
  return {
    $: __1_MAP,
    __func: f,
    __decoders: decoders,
  };
}

const _Json_andThen = F2((callback, decoder) => {
  return {
    $: __1_AND_THEN,
    __decoder: decoder,
    __callback: callback,
  };
});

function _Json_oneOf(decoders) {
  return {
    $: __1_ONE_OF,
    __decoders: decoders,
  };
}

// DECODING OBJECTS

const _Json_map1 = F2((f, d1) => {
  return _Json_mapMany(f, [d1]);
});

const _Json_map2 = F3((f, d1, d2) => {
  return _Json_mapMany(f, [d1, d2]);
});

const _Json_map3 = F4((f, d1, d2, d3) => {
  return _Json_mapMany(f, [d1, d2, d3]);
});

const _Json_map4 = F5((f, d1, d2, d3, d4) => {
  return _Json_mapMany(f, [d1, d2, d3, d4]);
});

const _Json_map5 = F6((f, d1, d2, d3, d4, d5) => {
  return _Json_mapMany(f, [d1, d2, d3, d4, d5]);
});

const _Json_map6 = F7((f, d1, d2, d3, d4, d5, d6) => {
  return _Json_mapMany(f, [d1, d2, d3, d4, d5, d6]);
});

const _Json_map7 = F8((f, d1, d2, d3, d4, d5, d6, d7) => {
  return _Json_mapMany(f, [d1, d2, d3, d4, d5, d6, d7]);
});

const _Json_map8 = F9((f, d1, d2, d3, d4, d5, d6, d7, d8) => {
  return _Json_mapMany(f, [d1, d2, d3, d4, d5, d6, d7, d8]);
});

// DECODE

const _Json_runOnString = F2((decoder, string) => {
  try {
    const value = JSON.parse(string);
    return _Json_runHelp(decoder, value);
  } catch (error) {
    return __Result_Err(
      A2(__Json_Failure, "This is not valid JSON! " + error.message, _Json_wrap(string))
    );
  }
});

const _Json_run = F2((decoder, value) => {
  return _Json_runHelp(decoder, _Json_unwrap(value));
});

function _Json_runHelp(decoder, value) {
  switch (decoder.$) {
    case __1_PRIM:
      return decoder.__decoder(value);

    case __1_NULL:
      return value === null ? __Result_Ok(decoder.__value) : _Json_expecting("null", value);

    case __1_LIST:
      if (!_Json_isArray(value)) {
        return _Json_expecting("a LIST", value);
      }

      return _Json_runArrayDecoder(decoder.__decoder, value, __List_fromArray);

    case __1_ARRAY:
      if (!_Json_isArray(value)) {
        return _Json_expecting("an ARRAY", value);
      }

      return _Json_runArrayDecoder(decoder.__decoder, value, _Json_toElmArray);

    case __1_FIELD:
      var field = decoder.__field;
      if (typeof value !== "object" || value === null || !(field in value)) {
        return _Json_expecting("an OBJECT with a field named `" + field + "`", value);
      }

      var result = _Json_runHelp(decoder.__decoder, value[field]);
      return __Result_isOk(result) ? result : __Result_Err(A2(__Json_Field, field, result.a));

    case __1_INDEX:
      var index = decoder.__index;
      if (!_Json_isArray(value)) {
        return _Json_expecting("an ARRAY", value);
      }

      if (index >= value.length) {
        return _Json_expecting(
          "a LONGER array. Need index " + index + " but only see " + value.length + " entries",
          value
        );
      }

      var result = _Json_runHelp(decoder.__decoder, value[index]);
      return __Result_isOk(result) ? result : __Result_Err(A2(__Json_Index, index, result.a));

    case __1_KEY_VALUE:
      if (typeof value !== "object" || value === null || _Json_isArray(value)) {
        return _Json_expecting("an OBJECT", value);
      }

      var keyValuePairs = __List_Nil;
      // TODO test perf of Object.keys and switch when support is good enough
      for (const key in value) {
        if (value.hasOwnProperty(key)) {
          var result = _Json_runHelp(decoder.__decoder, value[key]);
          if (!__Result_isOk(result)) {
            return __Result_Err(A2(__Json_Field, key, result.a));
          }

          keyValuePairs = __List_Cons(__Utils_Tuple2(key, result.a), keyValuePairs);
        }
      }

      return __Result_Ok(__List_reverse(keyValuePairs));

    case __1_MAP:
      var answer = decoder.__func;
      var decoders = decoder.__decoders;
      for (const decoder_ of decoders) {
        var result = _Json_runHelp(decoder_, value);
        if (!__Result_isOk(result)) {
          return result;
        }

        answer = answer(result.a);
      }

      return __Result_Ok(answer);

    case __1_AND_THEN:
      var result = _Json_runHelp(decoder.__decoder, value);
      return !__Result_isOk(result) ? result : _Json_runHelp(decoder.__callback(result.a), value);

    case __1_ONE_OF:
      var errors = __List_Nil;
      for (
        let temporary = decoder.__decoders;
        temporary.b;
        temporary = temporary.b // WHILE_CONS
      ) {
        var result = _Json_runHelp(temporary.a, value);
        if (__Result_isOk(result)) {
          return result;
        }

        errors = __List_Cons(result.a, errors);
      }

      return __Result_Err(__Json_OneOf(__List_reverse(errors)));

    case __1_FAIL:
      return __Result_Err(A2(__Json_Failure, decoder.__msg, _Json_wrap(value)));

    case __1_SUCCEED:
      return __Result_Ok(decoder.__msg);
  }
}

function _Json_runArrayDecoder(decoder, value, toElmValue) {
  const length_ = value.length;
  const array = new Array(length_);
  for (let i = 0; i < length_; i++) {
    const result = _Json_runHelp(decoder, value[i]);
    if (!__Result_isOk(result)) {
      return __Result_Err(A2(__Json_Index, i, result.a));
    }

    array[i] = result.a;
  }

  return __Result_Ok(toElmValue(array));
}

function _Json_isArray(value) {
  return Array.isArray(value) || (typeof FileList !== "undefined" && value instanceof FileList);
}

function _Json_toElmArray(array) {
  return A2(__Array_initialize, array.length, (i) => {
    return array[i];
  });
}

function _Json_expecting(type, value) {
  return __Result_Err(A2(__Json_Failure, "Expecting " + type, _Json_wrap(value)));
}

// EQUALITY

function _Json_equality(x, y) {
  if (x === y) {
    return true;
  }

  if (x.$ !== y.$) {
    return false;
  }

  switch (x.$) {
    case __1_SUCCEED:
    case __1_FAIL:
      return x.__msg === y.__msg;

    case __1_PRIM:
      return x.__decoder === y.__decoder;

    case __1_NULL:
      return x.__value === y.__value;

    case __1_LIST:
    case __1_ARRAY:
    case __1_KEY_VALUE:
      return _Json_equality(x.__decoder, y.__decoder);

    case __1_FIELD:
      return x.__field === y.__field && _Json_equality(x.__decoder, y.__decoder);

    case __1_INDEX:
      return x.__index === y.__index && _Json_equality(x.__decoder, y.__decoder);

    case __1_MAP:
      return x.__func === y.__func && _Json_listEquality(x.__decoders, y.__decoders);

    case __1_AND_THEN:
      return x.__callback === y.__callback && _Json_equality(x.__decoder, y.__decoder);

    case __1_ONE_OF:
      return _Json_listEquality(x.__decoders, y.__decoders);
  }
}

function _Json_listEquality(aDecoders, bDecoders) {
  const length_ = aDecoders.length;
  if (length_ !== bDecoders.length) {
    return false;
  }

  for (let i = 0; i < length_; i++) {
    if (!_Json_equality(aDecoders[i], bDecoders[i])) {
      return false;
    }
  }

  return true;
}

// ENCODE

const _Json_encode = F2((indentLevel, value) => {
  return String(JSON.stringify(_Json_unwrap(value), null, indentLevel));
});

function _Json_wrap__DEBUG(value) {
  return { $: __0_JSON, a: value };
}

function _Json_unwrap__DEBUG(value) {
  return value.a;
}

function _Json_wrap__PROD(value) {
  return value;
}

function _Json_unwrap__PROD(value) {
  return value;
}

function _Json_emptyArray() {
  return [];
}

function _Json_emptyObject() {
  return {};
}

const _Json_addField = F3((key, value, object) => {
  object[key] = _Json_unwrap(value);
  return object;
});

function _Json_addEntry(func) {
  return F2((entry, array) => {
    array.push(_Json_unwrap(func(entry)));
    return array;
  });
}

const _Json_encodeNull = _Json_wrap(null);

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Json_.*" }] */

/* global __Array_initialize */
/* global __List_Cons, __List_Nil, __List_fromArray */
/* global __Utils_Tuple2 */
/* global __Json_Field, __Json_Index, __Json_OneOf, __Json_Failure, __Json_errorToString */
/* global __List_reverse */
/* global __Maybe_Just, __Maybe_Nothing */
/* global __Result_Ok, __Result_Err, __Result_isOk */
