# Core

The most basic elm modules, supported in the browser and on node (http requires
a fetch polyfill). This package contains "another version" of the following
offical packages:

1. elm/core
2. elm/time
3. elm/random
4. elm/bytes
5. The `File` modules from elm/file. (Other modules will be part of the browser package.)
6. elm/http
7. elm/parser

## Bytes

Work with densely packed sequences of bytes.

The goal of this package is to support **network protocols** such as ProtoBuf. Or to put it another way, the goal is to have packages like `elm/http` send fewer bytes over the wire.

### Motivation = [A vision for data interchange in Elm](https://gist.github.com/evancz/1c5f2cf34939336ecb79b97bb89d9da6)

Please read it!

### Example

This package lets you create encoders and decoders for working with sequences of bytes. Here is an example for converting between `Point` and `Bytes` values:

```elm
import Bytes exposing (Endianness(..))
import Bytes.Encode as Encode exposing (Encoder)
import Bytes.Decode as Decode exposing (Decoder)


-- POINT

type alias Point =
  { x : Float
  , y : Float
  , z : Float
  }

toPointEncoder : Point -> Encoder
toPointEncoder point =
  Encode.sequence
    [ Encode.float32 BE point.x
    , Encode.float32 BE point.y
    , Encode.float32 BE point.z
    ]

pointDecoder : Decoder Point
pointDecoder =
  Decode.map3 Point
    (Decode.float32 BE)
    (Decode.float32 BE)
    (Decode.float32 BE)
```

Rather than writing this by hand in client or server code, the hope is that folks implement things like ProtoBuf compilers for Elm.

Again, the overall plan is described in [**A vision for data interchange in Elm**](https://gist.github.com/evancz/1c5f2cf34939336ecb79b97bb89d9da6)!

### Scope

**This API is not intended to work like `Int8Array` or `Uint16Array` in JavaScript.** If you have a concrete scenario in which you want to interpret bytes as densely packed arrays of integers or floats, please describe it on [https://discourse.elm-lang.org/](https://discourse.elm-lang.org/) in a friendly and high-level way. What is the project about? What do densely packed arrays do for that project? Is it about perf? What kind of algorithms are you using? Etc.

If some scenarios require the mutation of entries in place, special care will be required in designing a nice API. All values in Elm are immutable, so the particular API that works well for us will probably depend a lot on the particulars of what folks are trying to do.

## HTTP

Make HTTP requests in Elm. Talk to servers.

**I very highly recommend reading through [The Official Guide](https://guide.elm-lang.org) to understand how to use this package!**

### Examples

Here are some commands you might create to send HTTP requests with this package:

```elm
import Http
import Json.Decode as D

type Msg
  = GotBook (Result Http.Error String)
  | GotItems (Result Http.Error (List String))

getBook : Cmd Msg
getBook =
  Http.get
    { url = "https://elm-lang.org/assets/public-opinion.txt"
    , expect = Http.expectString GotBook
    }

fetchItems : Cmd Msg
fetchItems =
  Http.post
    { url = "https://example.com/items.json"
    , body = Http.emptyBody
    , expect = Http.expectJson GotItems (D.list (D.field "name" D.string))
    }
```

But again, to really understand what is going on here, **read through [The Official Guide](https://guide.elm-lang.org).** It has sections describing how HTTP works and how to use it with JSON data. Reading through will take less time overall than trying to figure everything out by trial and error!

## Parser

Regular expressions are quite confusing and difficult to use. The `Parser` and
`Parser.Advanced` modules provide a coherent alternative that handles more
cases and produces clearer code.

The particular goals of this library are:

- Make writing parsers as simple and fun as possible.
- Produce excellent error messages.
- Go pretty fast.

This is achieved with a couple concepts that I have not seen in any other parser libraries: [parser pipelines](#parser-pipelines), [backtracking](#backtracking), and [tracking context](#tracking-context).

### Parser Pipelines

To parse a 2D point like `( 3, 4 )`, you might create a `point` parser like this:

```elm
import Parser exposing (Parser, (|.), (|=), succeed, symbol, float, spaces)

type alias Point =
  { x : Float
  , y : Float
  }

point : Parser Point
point =
  succeed Point
    |. symbol "("
    |. spaces
    |= float
    |. spaces
    |. symbol ","
    |. spaces
    |= float
    |. spaces
    |. symbol ")"
```

All the interesting stuff is happening in `point`. It uses two operators:

- [`(|.)`][ignore] means “parse this, but **ignore** the result”
- [`(|=)`][keep] means “parse this, and **keep** the result”

So the `Point` function only gets the result of the two `float` parsers.

[ignore]: https://package.elm-lang.org/packages/elm/parser/latest/Parser#|.
[keep]: https://package.elm-lang.org/packages/elm/parser/latest/Parser#|=

The theory is that `|=` introduces more “visual noise” than `|.`, making it pretty easy to pick out which lines in the pipeline are important.

I recommend having one line per operator in your parser pipeline. If you need multiple lines for some reason, use a `let` or make a helper function.

### Backtracking

To make fast parsers with precise error messages, all of the parsers in this package do not backtrack by default. Once you start going down a path, you keep going down it.

This is nice in a string like `[ 1, 23zm5, 3 ]` where you want the error at the `z`. If we had backtracking by default, you might get the error on `[` instead. That is way less specific and harder to fix!

So the defaults are nice, but sometimes the easiest way to write a parser is to look ahead a bit and see what is going to happen. It is definitely more costly to do this, but it can be handy if there is no other way. This is the role of [`backtrackable`](https://package.elm-lang.org/packages/elm/parser/latest/Parser#backtrackable) parsers. Check out the [semantics](https://github.com/elm/parser/blob/master/semantics.md) page for more details!

### Tracking Context

Most parsers tell you the row and column of the problem:

```text
Something went wrong at (4:17)
```

That may be true, but it is not how humans think. It is how text editors think! It would be better to say:

```text
I found a problem with this list:

    [ 1, 23zm5, 3 ]
          ^
I wanted an integer, like 6 or 90219.
```

Notice that the error messages says `this list`. That is context! That is the language my brain speaks, not rows and columns.

Once you get comfortable with the `Parser` module, you can switch over to `Parser.Advanced` and use [`inContext`](https://package.elm-lang.org/packages/elm/parser/latest/Parser-Advanced#inContext) to track exactly what your parser thinks it is doing at the moment. You can let the parser know “I am trying to parse a `"list"` right now” so if an error happens anywhere in that context, you get the hand annotation!

This technique is used by the parser in the Elm compiler to give more helpful error messages.

### [Comparison with Prior Work](https://github.com/elm/parser/blob/master/comparison.md)
