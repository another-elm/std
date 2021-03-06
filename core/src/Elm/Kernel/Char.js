/*

import Elm.Kernel.Utils exposing (chr)

*/

function _Char_toCode(char) {
  return char.codePointAt(0);
}

function _Char_fromCode(code) {
  return __Utils_chr(code < 0 || code > 0x10ffff ? "\uFFFD" : String.fromCodePoint(code));
}

function _Char_toUpper(char) {
  return __Utils_chr(char.toUpperCase());
}

function _Char_toLower(char) {
  return __Utils_chr(char.toLowerCase());
}

function _Char_toLocaleUpper(char) {
  return __Utils_chr(char.toLocaleUpperCase());
}

function _Char_toLocaleLower(char) {
  return __Utils_chr(char.toLocaleLowerCase());
}

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Char_.*" }] */

/* global __Utils_chr */
