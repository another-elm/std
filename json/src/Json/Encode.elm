module Json.Encode exposing
    ( encode, Value(..)
    , string, int, float, bool, null
    , list, array, set
    , object, dict
    )

{-| Library for turning Elm values into Json values.


# Encoding

@docs encode, Value


# Primitives

@docs string, int, float, bool, null


# Arrays

@docs list, array, set


# Objects

@docs object, dict

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Elm.Kernel.Basics
import Elm.Kernel.Json
import Json.Internal
import Platform.Unstable.Effect as Effect
import Platform.Unstable.Iterable as Iterable
import Set exposing (Set)



-- ENCODE


{-| Represents a JavaScript value.
-}
type
    Value
    -- MUST BE A TYPE
    = Value Json.Internal.Value


{-| Convert a `Value` into a prettified string. The first argument specifies
the amount of indentation in the resulting string.

    import Json.Encode as Encode

    tom : Encode.Value
    tom =
        Encode.object
            [ ( "name", Encode.string "Tom" )
            , ( "age", Encode.int 42 )
            ]

    compact =
        Encode.encode 0 tom

    -- {"name":"Tom","age":42}
    readable =
        Encode.encode 4 tom

    -- {
    --     "name": "Tom",
    --     "age": 42
    -- }

todo(harry): fix formatting

-}
encode : Int -> Value -> String
encode indent (Value (Json.Internal.Value raw)) =
    encodeRaw indent raw



-- PRIMITIVES


{-| Turn a `String` into a JSON string.

    import Json.Encode exposing (encode, string)


    -- encode 0 (string "")      == "\"\""
    -- encode 0 (string "abc")   == "\"abc\""
    -- encode 0 (string "hello") == "\"hello\""

-}
string : String -> Value
string s =
    let
        raw : Effect.RawJsObject
        raw =
            Elm.Kernel.Basics.fudgeType s
    in
    Value (Json.Internal.Value raw)


{-| Turn an `Int` into a JSON number.

    import Json.Encode exposing (encode, int)


    -- encode 0 (int 42) == "42"
    -- encode 0 (int -7) == "-7"
    -- encode 0 (int 0)  == "0"

-}
int : Int -> Value
int i =
    let
        raw : Effect.RawJsObject
        raw =
            Elm.Kernel.Basics.fudgeType i
    in
    Value (Json.Internal.Value raw)


{-| Turn a `Float` into a JSON number.

    import Json.Encode exposing (encode, float)


    -- encode 0 (float 3.14)     == "3.14"
    -- encode 0 (float 1.618)    == "1.618"
    -- encode 0 (float -42)      == "-42"
    -- encode 0 (float NaN)      == "null"
    -- encode 0 (float Infinity) == "null"

**Note:** Floating point numbers are defined in the [IEEE 754 standard][ieee]
which is hardcoded into almost all CPUs. This standard allows `Infinity` and
`NaN`. [The JSON spec][json] does not include these values, so we encode them
both as `null`.

[ieee]: https://en.wikipedia.org/wiki/IEEE_754
[json]: https://www.json.org/

-}
float : Float -> Value
float f =
    let
        raw : Effect.RawJsObject
        raw =
            Elm.Kernel.Basics.fudgeType f
    in
    Value (Json.Internal.Value raw)


{-| Turn a `Bool` into a JSON boolean.

    import Json.Encode exposing (bool, encode)


    -- encode 0 (bool True)  == "true"
    -- encode 0 (bool False) == "false"

-}
bool : Bool -> Value
bool b =
    let
        raw : Effect.RawJsObject
        raw =
            Elm.Kernel.Basics.fudgeType b
    in
    Value (Json.Internal.Value raw)



-- NULLS


{-| Create a JSON `null` value.

    import Json.Encode exposing (encode, null)


    -- encode 0 null == "null"

-}
null : Value
null =
    Value (Json.Internal.Value nullRaw)



-- ARRAYS


{-| Turn a `List` into a JSON array.

    import Json.Encode as Encode exposing (bool, encode, int, list, string)


    -- encode 0 (list int [1,3,4])       == "[1,3,4]"
    -- encode 0 (list bool [True,False]) == "[true,false]"
    -- encode 0 (list string ["a","b"])  == """["a","b"]"""

-}
list : (a -> Value) -> List a -> Value
list func entries =
    iterableArray func (Iterable.list entries)


{-| Turn an `Array` into a JSON array.
-}
array : (a -> Value) -> Array a -> Value
array func entries =
    iterableArray func (Iterable.array entries)


{-| Turn an `Set` into a JSON array.
-}
set : (a -> Value) -> Set a -> Value
set func entries =
    iterableArray func (Iterable.set entries)



-- OBJECTS


{-| Create a JSON object.

    import Json.Encode as Encode

    tom : Encode.Value
    tom =
        Encode.object
            [ ( "name", Encode.string "Tom" )
            , ( "age", Encode.int 42 )
            ]

    -- Encode.encode 0 tom == """{"name":"Tom","age":42}"""

-}
object : List ( String, Value ) -> Value
object pairs =
    iterableObj (\x -> x) (\x -> x) (Iterable.list pairs)


{-| Turn a `Dict` into a JSON object.

    import Dict exposing (Dict)
    import Json.Encode as Encode

    people : Dict String Int
    people =
        Dict.fromList [ ( "Tom", 42 ), ( "Sue", 38 ) ]

    -- Encode.encode 0 (Encode.dict identity Encode.int people)
    --   == """{"Tom":42,"Sue":38}"""

-}
dict : (k -> String) -> (v -> Value) -> Dict k v -> Value
dict toKey toValue dictionary =
    iterableObj toKey toValue (Iterable.dict dictionary)


iterableArray : (a -> Value) -> Iterable.Iterable a -> Value
iterableArray func entries =
    let
        unwrappedFunc v =
            let
                (Value (Json.Internal.Value wrapped)) =
                    func v
            in
            wrapped
    in
    Value (Json.Internal.Value (arrayFrom unwrappedFunc entries))


iterableObj : (k -> String) -> (v -> Value) -> Iterable.Iterable ( k, v ) -> Value
iterableObj keyFunc valueFunc entries =
    let
        unwrappedValueFunc v =
            let
                (Value (Json.Internal.Value wrapped)) =
                    valueFunc v
            in
            wrapped
    in
    Value (Json.Internal.Value (objectFrom keyFunc unwrappedValueFunc entries))



-- Kernel interop


unwrap : Value -> Json.Internal.Value
unwrap (Value val) =
    val


encodeRaw : Int -> Effect.RawJsObject -> String
encodeRaw =
    Elm.Kernel.Json.encode


nullRaw : Effect.RawJsObject
nullRaw =
    Elm.Kernel.Json.null


arrayFrom : (a -> Effect.RawJsObject) -> Iterable.Iterable a -> Effect.RawJsObject
arrayFrom =
    Elm.Kernel.Json.arrayFrom


objectFrom : (k -> String) -> (v -> Effect.RawJsObject) -> Iterable.Iterable ( k, v ) -> Effect.RawJsObject
objectFrom =
    Elm.Kernel.Json.objectFrom
