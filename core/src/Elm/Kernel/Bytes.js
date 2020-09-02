/*

import Bytes.Encode as Encode exposing (getWidth, write)
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

function _Bytes_encode(encoder) {
  const mutableBytes = new DataView(new ArrayBuffer(__Encode_getWidth(encoder)));
  __Encode_write(encoder)(mutableBytes)(0);
  return mutableBytes;
}

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
  for (var width = 0, i = 0; i < string.length; i++) {
    const code = string.charCodeAt(i);
    width += code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0xd800 || code > 0xdbff ? 3 : (i++, 4);
  }

  return width;
}

const _Bytes_write_string = F3(function (mb, offset, string) {
  for (let i = 0; i < string.length; i++) {
    let code = string.charCodeAt(i);
    offset +=
      code < 0x80
        ? (mb.setUint8(offset, code), 1)
        : code < 0x800
        ? (mb.setUint16(
            offset,
            0xc080 /* 0b1100000010000000 */ |
              (((code >>> 6) & 0x1f) /* 0b00011111 */ << 8) |
              (code & 0x3f) /* 0b00111111 */
          ),
          2)
        : code < 0xd800 || code > 0xdbff
        ? (mb.setUint16(
            offset,
            0xe080 /* 0b1110000010000000 */ |
              (((code >>> 12) & 0xf) /* 0b00001111 */ << 8) |
              ((code >>> 6) & 0x3f) /* 0b00111111 */
          ),
          mb.setUint8(offset + 2, 0x80 /* 0b10000000 */ | (code & 0x3f) /* 0b00111111 */),
          3)
        : ((code = (code - 0xd800) * 0x400 + string.charCodeAt(++i) - 0xdc00 + 0x10000),
          mb.setUint32(
            offset,
            0xf0808080 /* 0b11110000100000001000000010000000 */ |
              (((code >>> 18) & 0x7) /* 0b00000111 */ << 24) |
              (((code >>> 12) & 0x3f) /* 0b00111111 */ << 16) |
              (((code >>> 6) & 0x3f) /* 0b00111111 */ << 8) |
              (code & 0x3f) /* 0b00111111 */
          ),
          4);
  }

  return offset;
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
  const sliceView = new DataView(bytes.buffer, bytes.byteOffset, length);

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

/* global __Encode_getWidth, __Encode_write */
/* global __Scheduler_binding, __Scheduler_succeed */
/* global __Utils_Tuple2, __Utils_chr */
/* global __Maybe_Just, __Maybe_Nothing */
