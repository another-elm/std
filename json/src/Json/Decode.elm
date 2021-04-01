module Json.Decode exposing
    ( Decoder, string, bool, int, float
    , nullable, list, array, dict, keyValuePairs, oneOrMore
    , field, at, index
    , maybe, oneOf
    , decodeString, decodeValue, Value, Error(..), errorToString
    , map, map2, map3, map4, map5, map6, map7, map8
    , lazy, value, null, succeed, fail, andThen
    )

{-| Turn JSON values into Elm values. Definitely check out this [intro to
JSON decoders][guide] to get a feel for how this library works!

[guide]: https://guide.elm-lang.org/effects/json.html


# Primitives

@docs Decoder, string, bool, int, float


# Data Structures

@docs nullable, list, array, dict, keyValuePairs, oneOrMore


# Object Primitives

@docs field, at, index


# Inconsistent Structure

@docs maybe, oneOf


# Run Decoders

@docs decodeString, decodeValue, Value, Error, errorToString


# Mapping

**Note:** If you run out of map functions, take a look at [elm-json-decode-pipeline][pipe]
which makes it easier to handle large objects, but produces lower quality type
errors.

[pipe]: /packages/NoRedInk/elm-json-decode-pipeline/latest

@docs map, map2, map3, map4, map5, map6, map7, map8


# Fancy Decoding

@docs lazy, value, null, succeed, fail, andThen

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Elm.Kernel.Json
import Json.Encode
import Json.Internal
import Platform.Unstable.Effect as Effect
import Platform.Unstable.Iterable as Iterable exposing (Iterable)



-- PRIMITIVES


{-| A value that knows how to decode JSON values.

There is a whole section in `guide.elm-lang.org` about decoders, so [check it
out](https://guide.elm-lang.org/interop/json.html) for a more comprehensive
introduction!

-}
type Decoder a
    = Decoder (Effect.RawJsObject -> Result Error a)


{-| Decode a JSON string into an Elm `String`.

    decodeString string "true"              == Err ...
    decodeString string "42"                == Err ...
    decodeString string "3.14"              == Err ...
    decodeString string "\"hello\""         == Ok "hello"
    decodeString string "{ \"hello\": 42 }" == Err ...

-}
string : Decoder String
string =
    prim decodeStringRaw "a STRING"


{-| Decode a JSON boolean into an Elm `Bool`.

    decodeString bool "true"              == Ok True
    decodeString bool "42"                == Err ...
    decodeString bool "3.14"              == Err ...
    decodeString bool "\"hello\""         == Err ...
    decodeString bool "{ \"hello\": 42 }" == Err ...

-}
bool : Decoder Bool
bool =
    prim decodeBool "a BOOL"


{-| Decode a JSON number into an Elm `Int`.

    decodeString int "true"              == Err ...
    decodeString int "42"                == Ok 42
    decodeString int "3.14"              == Err ...
    decodeString int "\"hello\""         == Err ...
    decodeString int "{ \"hello\": 42 }" == Err ...

-}
int : Decoder Int
int =
    prim decodeInt "an INT"


{-| Decode a JSON number into an Elm `Float`.

    decodeString float "true"              == Err ..
    decodeString float "42"                == Ok 42
    decodeString float "3.14"              == Ok 3.14
    decodeString float "\"hello\""         == Err ...
    decodeString float "{ \"hello\": 42 }" == Err ...

-}
float : Decoder Float
float =
    prim decodeFloat "a FLOAT"



-- DATA STRUCTURES


{-| Decode a nullable JSON value into an Elm value.

    decodeString (nullable int) "13"    == Ok (Just 13)
    decodeString (nullable int) "42"    == Ok (Just 42)
    decodeString (nullable int) "null"  == Ok Nothing
    decodeString (nullable int) "true"  == Err ..

-}
nullable : Decoder a -> Decoder (Maybe a)
nullable decoder =
    oneOf
        [ null Nothing
        , map Just decoder
        ]


{-| Decode a JSON array into an Elm `List`.

    decodeString (list int) "[1,2,3]" == Ok [ 1, 2, 3 ]

    decodeString (list bool) "[true,false]" == Ok [ True, False ]

-}
list : Decoder a -> Decoder (List a)
list (Decoder decoder) =
    Decoder
        (\raw ->
            decodeArray raw
                |> Result.fromMaybe (Failure "Expecting a LIST" (Json.Encode.Value (Json.Internal.Value raw)))
                |> Result.andThen (Iterable.tryMap decoder)
                |> Result.map Iterable.toList
        )


{-| Decode a JSON array into an Elm `Array`.

    decodeString (array int) "[1,2,3]" == Ok (Array.fromList [ 1, 2, 3 ])

    decodeString (array bool) "[true,false]" == Ok (Array.fromList [ True, False ])

-}
array : Decoder a -> Decoder (Array a)
array (Decoder decoder) =
    Decoder
        (\raw ->
            decodeArray raw
                |> Result.fromMaybe (Failure "Expecting an ARRAY" (Json.Encode.Value (Json.Internal.Value raw)))
                |> Result.andThen (Iterable.tryMap decoder)
                |> Result.map Iterable.toArray
        )


{-| Decode a JSON object into an Elm `Dict`.

    decodeString (dict int) "{ \"alice\": 42, \"bob\": 99 }"
        == Ok (Dict.fromList [ ( "alice", 42 ), ( "bob", 99 ) ])

If you need the keys (like `"alice"` and `"bob"`) available in the `Dict`
values as well, I recommend using a (private) intermediate data structure like
`Info` in this example:

    module User exposing (User, decoder)

    import Dict
    import Json.Decode exposing (..)

    type alias User =
        { name : String
        , height : Float
        , age : Int
        }

    decoder : Decoder (Dict.Dict String User)
    decoder =
        map (Dict.map infoToUser) (dict infoDecoder)

    type alias Info =
        { height : Float
        , age : Int
        }

    infoDecoder : Decoder Info
    infoDecoder =
        map2 Info
            (field "height" float)
            (field "age" int)

    infoToUser : String -> Info -> User
    infoToUser name { height, age } =
        User name height age

So now JSON like `{ "alice": { height: 1.6, age: 33 }}` are turned into
dictionary values like `Dict.singleton "alice" (User "alice" 1.6 33)` if
you need that.

-}
dict : Decoder a -> Decoder (Dict String a)
dict decoder =
    Decoder (keyValueHelper decoder >> Result.map Iterable.toDict)


{-| Decode a JSON object into an Elm `List` of pairs.

    decodeString (keyValuePairs int) "{ \"alice\": 42, \"bob\": 99 }"
        == Ok [ ( "alice", 42 ), ( "bob", 99 ) ]

-}
keyValuePairs : Decoder a -> Decoder (List ( String, a ))
keyValuePairs decoder =
    Decoder (keyValueHelper decoder >> Result.map Iterable.toList)


{-| Decode a JSON array that has one or more elements. This comes up if you
want to enable drag-and-drop of files into your application. You would pair
this function with [`elm/file`]() to write a `dropDecoder` like this:

    import File exposing (File)
    import Json.Decoder as D

    type Msg
        = GotFiles File (List Files)

    inputDecoder : D.Decoder Msg
    inputDecoder =
        D.at [ "dataTransfer", "files" ] (D.oneOrMore GotFiles File.decoder)

This captures the fact that you can never drag-and-drop zero files.

-}
oneOrMore : (a -> List a -> value) -> Decoder a -> Decoder value
oneOrMore toValue decoder =
    list decoder
        |> andThen (oneOrMoreHelp toValue)


oneOrMoreHelp : (a -> List a -> value) -> List a -> Decoder value
oneOrMoreHelp toValue xs =
    case xs of
        [] ->
            fail "a ARRAY with at least ONE element"

        y :: ys ->
            succeed (toValue y ys)



-- OBJECT PRIMITIVES


{-| Decode a JSON object, requiring a particular field.

    decodeString (field "x" int) "{ \"x\": 3 }" == Ok 3

    decodeString (field "x" int) "{ \"x\": 3, \"y\": 4 }" == Ok 3

    decodeString (field "x" int) "{ \"x\": true }"
        == Err
        ... decodeString (field "x" int) "{ \"y\": 4 }"
        == Err
        ... decodeString (field "name" string) "{ \"name\": \"tom\" }"
        == Ok "tom"

TODO(harry): fix formatting

The object _can_ have other fields. Lots of them! The only thing this decoder
cares about is if `x` is present and that the value there is an `Int`.

Check out [`map2`](#map2) to see how to decode multiple fields!

-}
field : String -> Decoder a -> Decoder a
field name (Decoder decoder) =
    Decoder
        (\raw ->
            getField name raw
                |> Result.fromMaybe
                    (Failure
                        ("Expecting an OBJECT with a field named `" ++ name ++ "`")
                        (Json.Encode.Value (Json.Internal.Value raw))
                    )
                |> Result.andThen (decoder >> Result.mapError (Field name))
        )


{-| Decode a nested JSON object, requiring certain fields.

    json = """{ "person": { "name": "tom", "age": 42 } }"""

    decodeString (at ["person", "name"] string) json  == Ok "tom"
    decodeString (at ["person", "age" ] int   ) json  == Ok "42

This is really just a shorthand for saying things like:

    field "person" (field "name" string) == at [ "person", "name" ] string

-}
at : List String -> Decoder a -> Decoder a
at fields decoder =
    List.foldr field decoder fields


{-| Decode a JSON array, requiring a particular index.

    json = """[ "alice", "bob", "chuck" ]"""

    decodeString (index 0 string) json  == Ok "alice"
    decodeString (index 1 string) json  == Ok "bob"
    decodeString (index 2 string) json  == Ok "chuck"
    decodeString (index 3 string) json  == Err ...

-}
index : Int -> Decoder a -> Decoder a
index i (Decoder decoder) =
    Decoder
        (\raw ->
            getArrayLength raw
                |> Result.fromMaybe (Failure "Expecting an ARRAY" (Json.Encode.Value (Json.Internal.Value raw)))
                |> Result.andThen
                    (\length ->
                        if i < 0 then
                            Err
                                (Failure
                                    ("Cannot access index " ++ String.fromInt i ++ " as it is negative")
                                    (Json.Encode.Value (Json.Internal.Value raw))
                                )

                        else if i >= length then
                            Err
                                (Failure
                                    ("Expecting a LONGER array. Need index "
                                        ++ String.fromInt i
                                        ++ " but only see "
                                        ++ String.fromInt length
                                        ++ " entries"
                                    )
                                    (Json.Encode.Value (Json.Internal.Value raw))
                                )

                        else
                            decoder (uncheckedArrayGet i raw)
                                |> Result.mapError (Index i)
                    )
        )



-- WEIRD STRUCTURE


{-| Helpful for dealing with optional fields. Here are a few slightly different
examples:

    json = """{ "name": "tom", "age": 42 }"""

    decodeString (maybe (field "age"    int  )) json == Ok (Just 42)
    decodeString (maybe (field "name"   int  )) json == Ok Nothing
    decodeString (maybe (field "height" float)) json == Ok Nothing

    decodeString (field "age"    (maybe int  )) json == Ok (Just 42)
    decodeString (field "name"   (maybe int  )) json == Ok Nothing
    decodeString (field "height" (maybe float)) json == Err ...

Notice the last example! It is saying we _must_ have a field named `height` and
the content _may_ be a float. There is no `height` field, so the decoder fails.

Point is, `maybe` will make exactly what it contains conditional. For optional
fields, this means you probably want it _outside_ a use of `field` or `at`.

-}
maybe : Decoder a -> Decoder (Maybe a)
maybe decoder =
    oneOf
        [ map Just decoder
        , succeed Nothing
        ]


{-| Try a bunch of different decoders. This can be useful if the JSON may come
in a couple different formats. For example, say you want to read an array of
numbers, but some of them are `null`.

    import String

    badInt : Decoder Int
    badInt =
        oneOf [ int, null 0 ]

    -- decodeString (list badInt) "[1,2,null,4]" == Ok [1,2,0,4]

Why would someone generate JSON like this? Questions like this are not good
for your health. The point is that you can use `oneOf` to handle situations
like this!

You could also use `oneOf` to help version your data. Try the latest format,
then a few older ones that you still support. You could use `andThen` to be
even more particular if you wanted.

-}
oneOf : List (Decoder a) -> Decoder a
oneOf decoders =
    Decoder (oneOfHelp decoders [] >> Result.mapError OneOf)



-- MAPPING


{-| Transform a decoder. Maybe you just want to know the length of a string:

    import String

    stringLength : Decoder Int
    stringLength =
        map String.length string

It is often helpful to use `map` with `oneOf`, like when defining `nullable`:

    nullable : Decoder a -> Decoder (Maybe a)
    nullable decoder =
        oneOf
            [ null Nothing
            , map Just decoder
            ]

-}
map : (a -> value) -> Decoder a -> Decoder value
map mapper (Decoder decoder) =
    Decoder
        (decoder >> Result.map mapper)


{-| Try two decoders and then combine the result. We can use this to decode
objects with many fields:


    type alias Point =
        { x : Float, y : Float }

    point : Decoder Point
    point =
        map2 Point
            (field "x" float)
            (field "y" float)

    -- decodeString point """{ "x": 3, "y": 4 }""" == Ok { x = 3, y = 4 }

It tries each individual decoder and puts the result together with the `Point`
constructor.

-}
map2 : (a -> b -> value) -> Decoder a -> Decoder b -> Decoder value
map2 mapper (Decoder decoderA) (Decoder decoderB) =
    Decoder
        (\raw ->
            Result.map2
                mapper
                (decoderA raw)
                (decoderB raw)
        )


{-| Try three decoders and then combine the result. We can use this to decode
objects with many fields:


    type alias Person =
        { name : String, age : Int, height : Float }

    person : Decoder Person
    person =
        map3 Person
            (at [ "name" ] string)
            (at [ "info", "age" ] int)
            (at [ "info", "height" ] float)

    -- json = """{ "name": "tom", "info": { "age": 42, "height": 1.8 } }"""
    -- decodeString person json == Ok { name = "tom", age = 42, height = 1.8 }

Like `map2` it tries each decoder in order and then give the results to the
`Person` constructor. That can be any function though!

-}
map3 : (a -> b -> c -> value) -> Decoder a -> Decoder b -> Decoder c -> Decoder value
map3 mapper (Decoder decoderA) (Decoder decoderB) (Decoder decoderC) =
    Decoder
        (\raw ->
            Result.map3
                mapper
                (decoderA raw)
                (decoderB raw)
                (decoderC raw)
        )


{-| -}
map4 : (a -> b -> c -> d -> value) -> Decoder a -> Decoder b -> Decoder c -> Decoder d -> Decoder value
map4 mapper (Decoder decoderA) (Decoder decoderB) (Decoder decoderC) (Decoder decoderD) =
    Decoder
        (\raw ->
            Result.map4
                mapper
                (decoderA raw)
                (decoderB raw)
                (decoderC raw)
                (decoderD raw)
        )


{-| -}
map5 : (a -> b -> c -> d -> e -> value) -> Decoder a -> Decoder b -> Decoder c -> Decoder d -> Decoder e -> Decoder value
map5 mapper (Decoder decoderA) (Decoder decoderB) (Decoder decoderC) (Decoder decoderD) (Decoder decoderE) =
    Decoder
        (\raw ->
            Result.map5
                mapper
                (decoderA raw)
                (decoderB raw)
                (decoderC raw)
                (decoderD raw)
                (decoderE raw)
        )


{-| -}
map6 : (a -> b -> c -> d -> e -> f -> value) -> Decoder a -> Decoder b -> Decoder c -> Decoder d -> Decoder e -> Decoder f -> Decoder value
map6 mapper decoderA decoderB decoderC decoderD decoderE decoderF =
    map2
        (\partiallyAppliedMapper -> partiallyAppliedMapper)
        (map5 mapper decoderA decoderB decoderC decoderD decoderE)
        decoderF


{-| -}
map7 : (a -> b -> c -> d -> e -> f -> g -> value) -> Decoder a -> Decoder b -> Decoder c -> Decoder d -> Decoder e -> Decoder f -> Decoder g -> Decoder value
map7 mapper decoderA decoderB decoderC decoderD decoderE decoderF decoderG =
    map3
        (\partiallyAppliedMapper -> partiallyAppliedMapper)
        (map5 mapper decoderA decoderB decoderC decoderD decoderE)
        decoderF
        decoderG


{-| -}
map8 : (a -> b -> c -> d -> e -> f -> g -> h -> value) -> Decoder a -> Decoder b -> Decoder c -> Decoder d -> Decoder e -> Decoder f -> Decoder g -> Decoder h -> Decoder value
map8 mapper decoderA decoderB decoderC decoderD decoderE decoderF decoderG decoderH =
    map4
        (\partiallyAppliedMapper -> partiallyAppliedMapper)
        (map5 mapper decoderA decoderB decoderC decoderD decoderE)
        decoderF
        decoderG
        decoderH



-- RUN DECODERS


{-| Parse the given string into a JSON value and then run the `Decoder` on it.
This will fail if the string is not well-formed JSON or if the `Decoder`
fails for some reason.

    decodeString int "4"     == Ok 4
    decodeString int "1 + 2" == Err ...

-}
decodeString : Decoder a -> String -> Result Error a
decodeString (Decoder decoder) string_ =
    case rawParse string_ of
        Ok raw ->
            decoder raw

        Err msg ->
            Err (Failure ("This is not valid JSON! " ++ msg) (Json.Encode.string string_))


{-| Run a `Decoder` on some JSON `Value`. You can send these JSON values
through ports, so that is probably the main time you would use this function.
-}
decodeValue : Decoder a -> Value -> Result Error a
decodeValue (Decoder decoder) (Json.Encode.Value (Json.Internal.Value raw)) =
    decoder raw


{-| Represents a JavaScript value.
-}
type alias Value =
    Json.Encode.Value


{-| A structured error describing exactly how the decoder failed. You can use
this to create more elaborate visualizations of a decoder problem. For example,
you could show the entire JSON object and show the part causing the failure in
red.
-}
type Error
    = Field String Error
    | Index Int Error
    | OneOf (List Error)
    | Failure String Value


{-| Convert a decoding error into a `String` that is nice for debugging.

It produces multiple lines of output, so you may want to peek at it with
something like this:

    import Html
    import Json.Decode as Decode

    errorToHtml : Decode.Error -> Html.Html msg
    errorToHtml error =
        Html.pre [] [ Html.text (Decode.errorToString error) ]

**Note:** It would be cool to do nicer coloring and fancier HTML, but I wanted
to avoid having an `elm/html` dependency for now. It is totally possible to
crawl the `Error` structure and create this separately though!

-}
errorToString : Error -> String
errorToString error =
    errorToStringHelp error []


errorToStringHelp : Error -> List String -> String
errorToStringHelp error context =
    case error of
        Field f err ->
            let
                isSimple =
                    case String.uncons f of
                        Nothing ->
                            False

                        Just ( char, rest ) ->
                            Char.isAlpha char && String.all Char.isAlphaNum rest

                fieldName =
                    if isSimple then
                        "." ++ f

                    else
                        "['" ++ f ++ "']"
            in
            errorToStringHelp err (fieldName :: context)

        Index i err ->
            let
                indexName =
                    "[" ++ String.fromInt i ++ "]"
            in
            errorToStringHelp err (indexName :: context)

        OneOf errors ->
            case errors of
                [] ->
                    "Ran into a Json.Decode.oneOf with no possibilities"
                        ++ (case context of
                                [] ->
                                    "!"

                                _ ->
                                    " at json" ++ String.join "" (List.reverse context)
                           )

                [ err ] ->
                    errorToStringHelp err context

                _ ->
                    let
                        starter =
                            case context of
                                [] ->
                                    "Json.Decode.oneOf"

                                _ ->
                                    "The Json.Decode.oneOf at json" ++ String.join "" (List.reverse context)

                        introduction =
                            starter ++ " failed in the following " ++ String.fromInt (List.length errors) ++ " ways:"
                    in
                    String.join "\n\n" (introduction :: List.indexedMap errorOneOf errors)

        Failure msg json ->
            let
                introduction =
                    case context of
                        [] ->
                            "Problem with the given value:\n\n"

                        _ ->
                            "Problem with the value at json" ++ String.join "" (List.reverse context) ++ ":\n\n    "
            in
            introduction ++ indent (Json.Encode.encode 4 json) ++ "\n\n" ++ msg


errorOneOf : Int -> Error -> String
errorOneOf i error =
    "\n\n(" ++ String.fromInt (i + 1) ++ ") " ++ indent (errorToString error)


indent : String -> String
indent str =
    String.join "\n    " (String.split "\n" str)



-- FANCY PRIMITIVES


{-| Ignore the JSON and produce a certain Elm value.

    decodeString (succeed 42) "true"    == Ok 42
    decodeString (succeed 42) "[1,2,3]" == Ok 42
    decodeString (succeed 42) "hello"   == Err ... -- this is not a valid JSON string

This is handy when used with `oneOf` or `andThen`.

-}
succeed : a -> Decoder a
succeed val =
    Decoder (\_ -> Ok val)


{-| Ignore the JSON and make the decoder fail. This is handy when used with
`oneOf` or `andThen` where you want to give a custom error message in some
case.

See the [`andThen`](#andThen) docs for an example.

-}
fail : String -> Decoder a
fail msg =
    Decoder (\raw -> Err (Failure msg (Json.Encode.Value (Json.Internal.Value raw))))


{-| Create decoders that depend on previous results. If you are creating
versioned data, you might do something like this:


    info : Decoder Info
    info =
        field "version" int
            |> andThen infoHelp

    infoHelp : Int -> Decoder Info
    infoHelp version =
        case version of
            4 ->
                infoDecoder4

            3 ->
                infoDecoder3

            _ ->
                fail <|
                    "Trying to decode info, but version "
                        ++ toString version
                        ++ " is not supported."

    -- infoDecoder4 : Decoder Info
    -- infoDecoder3 : Decoder Info

-}
andThen : (a -> Decoder b) -> Decoder a -> Decoder b
andThen func (Decoder decoder) =
    Decoder
        (\raw ->
            decoder raw
                |> Result.andThen
                    (\a ->
                        let
                            (Decoder newDecoder) =
                                func a
                        in
                        newDecoder raw
                    )
        )


{-| Sometimes you have JSON with recursive structure, like nested comments.
You can use `lazy` to make sure your decoder unrolls lazily.

    type alias Comment =
        { message : String
        , responses : Responses
        }

    type Responses
        = Responses (List Comment)

    comment : Decoder Comment
    comment =
        map2 Comment
            (field "message" string)
            (field "responses" (map Responses (list (lazy (\_ -> comment)))))

If we had said `list comment` instead, we would start expanding the value
infinitely. What is a `comment`? It is a decoder for objects where the
`responses` field contains comments. What is a `comment` though? Etc.

By using `list (lazy (\_ -> comment))` we make sure the decoder only expands
to be as deep as the JSON we are given. You can read more about recursive data
structures [here].

[here]: https://github.com/elm/compiler/blob/master/hints/recursive-alias.md

-}
lazy : (() -> Decoder a) -> Decoder a
lazy thunk =
    andThen thunk (succeed ())


{-| Do not do anything with a JSON value, just bring it into Elm as a `Value`.
This can be useful if you have particularly complex data that you would like to
deal with later. Or if you are going to send it out a port and do not care
about its structure.
-}
value : Decoder Value
value =
    Decoder (Json.Internal.Value >> Json.Encode.Value >> Ok)


{-| Decode a `null` value into some Elm value.

    decodeString (null False) "null" == Ok False
    decodeString (null 42) "null"    == Ok 42
    decodeString (null 42) "42"      == Err ..
    decodeString (null 42) "false"   == Err ..

So if you ever see a `null`, this will return whatever value you specified.

-}
null : a -> Decoder a
null val =
    Decoder
        (\raw ->
            if isNull raw then
                Ok val

            else
                Err (Failure "Expecting null" (Json.Encode.Value (Json.Internal.Value raw)))
        )


keyValueDecodeHelper : Decoder a -> List ( String, a ) -> List ( String, Value ) -> Result Error (List ( String, a ))
keyValueDecodeHelper decoder processed reversedRaw =
    case reversedRaw of
        [] ->
            Ok processed

        ( key, fieldValue ) :: rest ->
            case
                decodeValue decoder fieldValue
            of
                Ok decodedFieldValue ->
                    keyValueDecodeHelper decoder (( key, decodedFieldValue ) :: processed) rest

                Err e ->
                    Err (Field key e)


oneOfHelp : List (Decoder a) -> List Error -> Effect.RawJsObject -> Result (List Error) a
oneOfHelp decoders errors raw =
    case decoders of
        [] ->
            Err (List.reverse errors)

        (Decoder first) :: rest ->
            case first raw of
                Ok decoded ->
                    Ok decoded

                Err e ->
                    oneOfHelp rest (e :: errors) raw


prim : (Effect.RawJsObject -> Maybe a) -> String -> Decoder a
prim func expecting =
    Decoder
        (\raw ->
            func raw
                |> Result.fromMaybe (Failure ("Expecting " ++ expecting) (Json.Encode.Value (Json.Internal.Value raw)))
        )


keyValueHelper : Decoder a -> Effect.RawJsObject -> Result Error (Iterable ( String, a ))
keyValueHelper (Decoder decoder) raw =
    decodeObject raw
        |> Result.fromMaybe (Failure "Expecting an OBJECT" (Json.Encode.Value (Json.Internal.Value raw)))
        |> Result.andThen
            (Iterable.tryMap
                (\( name, rawFieldValue ) ->
                    case decoder raw of
                        Ok fieldValue ->
                            Ok ( name, fieldValue )

                        Err e ->
                            Err (Field name e)
                )
            )



-- Kernel interop


decodeStringRaw : Effect.RawJsObject -> Maybe String
decodeStringRaw =
    Elm.Kernel.Json.decodeString


decodeBool : Effect.RawJsObject -> Maybe Bool
decodeBool =
    Elm.Kernel.Json.decodeBool


decodeInt : Effect.RawJsObject -> Maybe Int
decodeInt =
    Elm.Kernel.Json.decodeInt


decodeFloat : Effect.RawJsObject -> Maybe Float
decodeFloat =
    Elm.Kernel.Json.decodeFloat


getField : String -> Effect.RawJsObject -> Maybe Effect.RawJsObject
getField =
    Elm.Kernel.Json.getField


getArrayLength : Effect.RawJsObject -> Maybe Int
getArrayLength =
    Elm.Kernel.Json.getArrayLength


uncheckedArrayGet : Int -> Effect.RawJsObject -> Effect.RawJsObject
uncheckedArrayGet =
    Elm.Kernel.Json.uncheckedArrayGet


rawParse : String -> Result String Effect.RawJsObject
rawParse =
    Elm.Kernel.Json.rawParse


decodeArray : Effect.RawJsObject -> Maybe (Iterable Effect.RawJsObject)
decodeArray =
    Elm.Kernel.Json.decodeArray


decodeObject : Effect.RawJsObject -> Maybe (Iterable ( String, Effect.RawJsObject ))
decodeObject =
    Elm.Kernel.Json.decodeObject


isNull : Effect.RawJsObject -> Bool
isNull =
    Elm.Kernel.Json.isNull
