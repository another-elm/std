/*

import Elm.Kernel.List exposing (fromArray, toArray)
import Elm.Kernel.Utils exposing (chr, Tuple2)
import Maybe exposing (Just, Nothing)
import List exposing (Nil_elm_builtin)

*/

const _String_cons = F2((chr, string) => {
  return chr + string;
});

function _String_uncons(string) {
  // eslint-disable-next-line no-unreachable-loop
  for (const firstChar of string) {
    return __Maybe_Just(__Utils_Tuple2(__Utils_chr(firstChar), string.slice(firstChar.length)));
  }

  return __Maybe_Nothing;
}

const _String_append = F2((a, b) => {
  return a + b;
});

function _String_length(string) {
  return string.length;
}

const _String_map = F2((func, string) => {
  const length = string.length;
  const array = Array.from({ length });
  let i = 0;
  while (i < length) {
    const word = string.charCodeAt(i);
    if (word >= 0xd800 && word <= 0xdbff) {
      array[i] = func(__Utils_chr(string[i] + string[i + 1]));
      i += 2;
      continue;
    }

    array[i] = func(__Utils_chr(string[i]));
    i++;
  }

  return array.join("");
});

const _String_filter = F2((isGood, string) => {
  const array = [];
  const length = string.length;
  let i = 0;
  while (i < length) {
    let char = string[i];
    const word = string.charCodeAt(i);
    i++;
    if (word >= 0xd800 && word <= 0xdbff) {
      char += string[i];
      i++;
    }

    if (isGood(__Utils_chr(char))) {
      array.push(char);
    }
  }

  return array.join("");
});

function _String_reverse(string) {
  const length = string.length;
  const array = Array.from({ length });
  let i = 0;
  while (i < length) {
    const word = string.charCodeAt(i);
    if (word >= 0xd800 && word <= 0xdbff) {
      array[length - i] = string[i + 1];
      i++;
      array[length - i] = string[i - 1];
      i++;
    } else {
      array[length - i] = string[i];
      i++;
    }
  }

  return array.join("");
}

const _String_foldl = F3((func, state, string) => {
  const length = string.length;
  let i = 0;
  while (i < length) {
    let char = string[i];
    const word = string.charCodeAt(i);
    i++;
    if (word >= 0xd800 && word <= 0xdbff) {
      char += string[i];
      i++;
    }

    state = A2(func, __Utils_chr(char), state);
  }

  return state;
});

const _String_foldr = F3((func, state, string) => {
  let i = string.length;
  while (i--) {
    let char = string[i];
    const word = string.charCodeAt(i);
    if (word >= 0xdc00 && word <= 0xdfff && i > 0) {
      i--;
      char = string[i] + char;
    }

    state = A2(func, __Utils_chr(char), state);
  }

  return state;
});

const _String_split = F2((sep, string) => {
  return string.split(sep);
});

const _String_join = F2((sep, strs) => {
  return strs.join(sep);
});

const _String_slice = F3((start, end, string) => {
  return string.slice(start, end);
});

function _String_trim(string) {
  return string.trim();
}

function _String_trimLeft(string) {
  return string.replace(/^\s+/, "");
}

function _String_trimRight(string) {
  return string.replace(/\s+$/, "");
}

function _String_words(string) {
  return __List_fromArray(string.trim().split(/\s+/g));
}

function _String_lines(string) {
  return __List_fromArray(string.split(/\r\n|\r|\n/g));
}

function _String_toUpper(string) {
  return string.toUpperCase();
}

function _String_toLower(string) {
  return string.toLowerCase();
}

const _String_any = F2((isGood, string) => {
  let i = string.length;
  while (i--) {
    let char = string[i];
    const word = string.charCodeAt(i);
    if (word >= 0xdc00 && word <= 0xdfff) {
      i--;
      char = string[i] + char;
    }

    if (isGood(__Utils_chr(char))) {
      return true;
    }
  }

  return false;
});

const _String_all = F2((isGood, string) => {
  let i = string.length;
  while (i--) {
    let char = string[i];
    const word = string.charCodeAt(i);
    if (word >= 0xdc00 && word <= 0xdfff) {
      i--;
      char = string[i] + char;
    }

    if (!isGood(__Utils_chr(char))) {
      return false;
    }
  }

  return true;
});

const _String_contains = F2((sub, string) => {
  return string.includes(sub);
});

const _String_startsWith = F2((sub, string) => {
  return string.indexOf(sub) === 0;
});

const _String_endsWith = F2((sub, string) => {
  return string.length >= sub.length && string.lastIndexOf(sub) === string.length - sub.length;
});

const _String_indexes = F2((sub, string) => {
  const subLength = sub.length;

  if (subLength < 1) {
    return __List_Nil_elm_builtin;
  }

  let i = 0;
  const is = [];

  while ((i = string.indexOf(sub, i)) > -1) {
    is.push(i);
    i += subLength;
  }

  return __List_fromArray(is);
});

// TO STRING

function _String_fromNumber(number) {
  return String(number);
}

// INT CONVERSIONS

function _String_toInt(string) {
  let total = 0;
  const code0 = string.charCodeAt(0);
  const start = code0 === 0x2b /* + */ || code0 === 0x2d /* - */ ? 1 : 0;
  let i = start;
  for (; i < string.length; ++i) {
    const code = string.charCodeAt(i);
    if (code < 0x30 || code > 0x39) {
      return __Maybe_Nothing;
    }

    total = 10 * total + code - 0x30;
  }

  return i === start ? __Maybe_Nothing : __Maybe_Just(code0 === 0x2d ? -total : total);
}

// FLOAT CONVERSIONS

function _String_toFloat(s) {
  // Check if it is a hex, octal, or binary number
  if (s.length === 0 || /[\sxbo]/.test(s)) {
    return __Maybe_Nothing;
  }

  const n = Number(s);
  return Number.isNaN(n) ? __Maybe_Nothing : __Maybe_Just(n);
}

function _String_fromList(chars) {
  return __List_toArray(chars).join("");
}

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_String_.*" }] */

/* global __List_fromArray, __List_toArray */
/* global __Utils_chr, __Utils_Tuple2 */
/* global __Maybe_Just, __Maybe_Nothing */
/* global __List_Nil_elm_builtin */
