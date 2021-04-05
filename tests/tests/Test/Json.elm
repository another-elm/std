module Test.Json exposing (tests)

import Basics exposing (..)
import Expect
import File
import Json.Decode as Json
import Json.Encode
import Result exposing (..)
import String
import Test exposing (..)


tests : Test
tests =
    describe "Json decode"
        [ intTests
        , customTests
        , fileTests
        ]


intTests : Test
intTests =
    let
        testInt val str =
            case Json.decodeString Json.int str of
                Ok _ ->
                    Expect.equal val True

                Err _ ->
                    Expect.equal val False
    in
    describe "Json decode int"
        [ test "whole int" <| \() -> testInt True "4"
        , test "-whole int" <| \() -> testInt True "-4"
        , test "whole float" <| \() -> testInt True "4.0"
        , test "-whole float" <| \() -> testInt True "-4.0"
        , test "large int" <| \() -> testInt True "1801439850948"
        , test "-large int" <| \() -> testInt True "-1801439850948"
        , test "float" <| \() -> testInt False "4.2"
        , test "-float" <| \() -> testInt False "-4.2"
        , test "Infinity" <| \() -> testInt False "Infinity"
        , test "-Infinity" <| \() -> testInt False "-Infinity"
        , test "NaN" <| \() -> testInt False "NaN"
        , test "-NaN" <| \() -> testInt False "-NaN"
        , test "true" <| \() -> testInt False "true"
        , test "false" <| \() -> testInt False "false"
        , test "string" <| \() -> testInt False "\"string\""
        , test "object" <| \() -> testInt False "{}"
        , test "null" <| \() -> testInt False "null"
        , test "undefined" <| \() -> testInt False "undefined"
        , test "Decoder expects object finds array, was crashing runtime." <|
            \() ->
                Expect.equal
                    (Err "Problem with the given value:\n\n[]\n\nExpecting an OBJECT")
                    (Result.mapError
                        Json.errorToString
                        (Json.decodeString (Json.dict Json.float) "[]")
                    )
        ]


customTests : Test
customTests =
    let
        jsonString =
            """{ "foo": "bar" }"""

        customErrorMessage =
            "I want to see this message!"

        myDecoder =
            Json.field "foo" Json.string |> Json.andThen (\_ -> Json.fail customErrorMessage)

        assertion =
            case Json.decodeString myDecoder jsonString of
                Ok _ ->
                    Expect.fail "expected `customDecoder` to produce a value of type Err, but got Ok"

                Err error ->
                    let
                        message =
                            Json.errorToString error
                    in
                    if String.contains customErrorMessage message then
                        Expect.pass

                    else
                        Expect.fail <|
                            "expected `customDecoder` to preserve user's error message '"
                                ++ customErrorMessage
                                ++ "', but instead got: "
                                ++ message
    in
    test "customDecoder preserves user error messages" <| \() -> assertion


fileTests : Test
fileTests =
    describe "Json decode file"
        [ test "error" <|
            \() ->
                "\"string\""
                    |> Json.decodeString File.decoder
                    |> Expect.equal
                        (Err
                            (Json.Failure "Expecting a FILE" (Json.Encode.string "string"))
                        )
        ]
