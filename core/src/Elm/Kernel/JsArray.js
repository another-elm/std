/*

import Elm.Kernel.Utils exposing (Tuple2)

*/

/* eslint-disable */

const _JsArray_empty = [];

function _JsArray_singleton(value) {
  return [value];
}

function _JsArray_length(array) {
  return array.length;
}

const _JsArray_initialize = F3(function (size, offset, func) {
  const result = new Array(size);

  for (let i = 0; i < size; i++) {
    result[i] = func(offset + i);
  }

  return result;
});

const _JsArray_initializeFromList = F2(function (max, ls) {
  const result = new Array(max);

  for (var i = 0; i < max && ls.b; i++) {
    result[i] = ls.a;
    ls = ls.b;
  }

  result.length = i;
  return __Utils_Tuple2(result, ls);
});

const _JsArray_unsafeGet = F2(function (index, array) {
  return array[index];
});

const _JsArray_unsafeSet = F3(function (index, value, array) {
  const length = array.length;
  const result = new Array(length);

  for (let i = 0; i < length; i++) {
    result[i] = array[i];
  }

  result[index] = value;
  return result;
});

const _JsArray_push = F2(function (value, array) {
  const length = array.length;
  const result = new Array(length + 1);

  for (let i = 0; i < length; i++) {
    result[i] = array[i];
  }

  result[length] = value;
  return result;
});

const _JsArray_foldl = F3(function (func, acc, array) {
  const length = array.length;

  for (let i = 0; i < length; i++) {
    acc = A2(func, array[i], acc);
  }

  return acc;
});

const _JsArray_foldr = F3(function (func, acc, array) {
  for (let i = array.length - 1; i >= 0; i--) {
    acc = A2(func, array[i], acc);
  }

  return acc;
});

const _JsArray_map = F2(function (func, array) {
  const length = array.length;
  const result = new Array(length);

  for (let i = 0; i < length; i++) {
    result[i] = func(array[i]);
  }

  return result;
});

const _JsArray_indexedMap = F3(function (func, offset, array) {
  const length = array.length;
  const result = new Array(length);

  for (let i = 0; i < length; i++) {
    result[i] = A2(func, offset + i, array[i]);
  }

  return result;
});

const _JsArray_slice = F3(function (from, to, array) {
  return array.slice(from, to);
});

const _JsArray_appendN = F3(function (n, dest, source) {
  const destLength = dest.length;
  let itemsToCopy = n - destLength;

  if (itemsToCopy > source.length) {
    itemsToCopy = source.length;
  }

  const size = destLength + itemsToCopy;
  const result = new Array(size);

  for (var i = 0; i < destLength; i++) {
    result[i] = dest[i];
  }

  for (var i = 0; i < itemsToCopy; i++) {
    result[i + destLength] = source[i];
  }

  return result;
});
