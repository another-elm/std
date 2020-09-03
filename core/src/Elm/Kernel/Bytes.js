/*

import Elm.Kernel.Scheduler exposing (binding, succeed)
import Elm.Kernel.Utils exposing (Tuple2, chr)
import Maybe exposing (Just, Nothing)

*/

/* eslint-disable */

// BYTES

function _Bytes_width(bytes) {
  return bytes.byteLength;
}

const _Bytes_getHostEndianness = F2(function (le, be) {
  return __Scheduler_binding(function (callback) {
    callback(__Scheduler_succeed(new Uint8Array(new Uint32Array([1]))[0] === 1 ? le : be));
  });
});

// ENCODERS

const _Bytes_newMutableBytesWith = (width) => (initialiser) => {
  const mutableBytes = new DataView(new ArrayBuffer(width));
  initialiser(mutableBytes);
  return mutableBytes;
};

// SIGNED INTEGERS

const _Bytes_write_i8 = F3(function (mb, i, n) {
  mb.setInt8(i, n);
  return i + 1;
});
const _Bytes_write_i16 = F4(function (mb, i, n, isLE) {
  mb.setInt16(i, n, isLE);
  return i + 2;
});
const _Bytes_write_i32 = F4(function (mb, i, n, isLE) {
  mb.setInt32(i, n, isLE);
  return i + 4;
});

// UNSIGNED INTEGERS

const _Bytes_write_u8 = F3(function (mb, i, n) {
  mb.setUint8(i, n);
  return i + 1;
});
const _Bytes_write_u16 = F4(function (mb, i, n, isLE) {
  mb.setUint16(i, n, isLE);
  return i + 2;
});
const _Bytes_write_u32 = F4(function (mb, i, n, isLE) {
  mb.setUint32(i, n, isLE);
  return i + 4;
});

// FLOATS

const _Bytes_write_f32 = F4(function (mb, i, n, isLE) {
  mb.setFloat32(i, n, isLE);
  return i + 4;
});
const _Bytes_write_f64 = F4(function (mb, i, n, isLE) {
  mb.setFloat64(i, n, isLE);
  return i + 8;
});

// BYTES

const _Bytes_write_bytes = F3(function (mb, offset, bytes) {
  // TODO(harry) consider aligning `offset + i` to a multiple of 4 here.
  for (var i = 0, length = bytes.byteLength, limit = length - 4; i <= limit; i += 4) {
    mb.setUint32(offset + i, bytes.getUint32(i));
  }

  for (; i < length; i++) {
    mb.setUint8(offset + i, bytes.getUint8(i));
  }

  return offset + length;
});

// STRINGS

function _Bytes_getStringWidth(string) {
  return (new TextEncoder().encode(string)).length;
}

const _Bytes_write_string = F3(function (mb, offset, string) {
  // TODO(harry): consider using encodeInto if it is available.
  const src = new TextEncoder().encode(string);
  const len = src.length;
  const dst = new Uint8Array(mb.buffer, mb.byteOffset + offset, len);
  dst.set(src);
  return offset + len;
});

// DECODER

const _Bytes_decode = F2(function (decoder, bytes) {
  try {
    return __Maybe_Just(A2(decoder, bytes, 0).b);
  } catch (error) {
    return __Maybe_Nothing;
  }
});

const _Bytes_read_i8 = F2(function (bytes, offset) {
  return __Utils_Tuple2(offset + 1, bytes.getInt8(offset));
});
const _Bytes_read_i16 = F3(function (isLE, bytes, offset) {
  return __Utils_Tuple2(offset + 2, bytes.getInt16(offset, isLE));
});
const _Bytes_read_i32 = F3(function (isLE, bytes, offset) {
  return __Utils_Tuple2(offset + 4, bytes.getInt32(offset, isLE));
});
const _Bytes_read_u8 = F2(function (bytes, offset) {
  return __Utils_Tuple2(offset + 1, bytes.getUint8(offset));
});
const _Bytes_read_u16 = F3(function (isLE, bytes, offset) {
  return __Utils_Tuple2(offset + 2, bytes.getUint16(offset, isLE));
});
const _Bytes_read_u32 = F3(function (isLE, bytes, offset) {
  return __Utils_Tuple2(offset + 4, bytes.getUint32(offset, isLE));
});
const _Bytes_read_f32 = F3(function (isLE, bytes, offset) {
  return __Utils_Tuple2(offset + 4, bytes.getFloat32(offset, isLE));
});
const _Bytes_read_f64 = F3(function (isLE, bytes, offset) {
  return __Utils_Tuple2(offset + 8, bytes.getFloat64(offset, isLE));
});

const _Bytes_read_bytes = F3(function (length, bytes, offset) {
  return __Utils_Tuple2(
    offset + length,
    new DataView(bytes.buffer, bytes.byteOffset + offset, length)
  );
});

const _Bytes_read_string = F3(function (length, bytes, offset) {
  const end = offset + length;
  const decoder = new TextDecoder('utf8', { fatal:  true});
  const sliceView = new DataView(bytes.buffer, bytes.byteOffset + offset, length);

  return __Utils_Tuple2(end, decoder.decode(sliceView));
});

const _Bytes_decodeFailure = F2(function () {
  throw 0;
});

/* ESLINT GLOBAL VARIABLES
 *
 * Do not edit below this line as it is generated by tests/generate-globals.py
 */

/* eslint no-unused-vars: ["error", { "varsIgnorePattern": "_Bytes_.*" }] */

/* global __Scheduler_binding, __Scheduler_succeed */
/* global __Utils_Tuple2, __Utils_chr */
/* global __Maybe_Just, __Maybe_Nothing */
