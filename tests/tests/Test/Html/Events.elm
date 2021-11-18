module Test.Html.Events exposing (jsonDecoderTests)

import Expect
import Fuzz
import Html.Events as E
import Json.Decode
import Json.Encode
import Test exposing (..)


eventJson : { value : String, checked : Bool, keyCode : Int } -> Json.Encode.Value
eventJson { value, checked, keyCode } =
    Json.Encode.object
        [ ( "target"
          , Json.Encode.object
                [ ( "value", Json.Encode.string value )
                , ( "checked", Json.Encode.bool checked )
                ]
          )
        , ( "keyCode", Json.Encode.int keyCode )
        ]


jsonDecoderTests : Test
jsonDecoderTests =
    let
        testDecoder value decoder expected =
            case Json.Decode.decodeValue decoder value of
                Ok a ->
                    Expect.equal a expected

                Err _ ->
                    Expect.fail "Could not decode"
    in
    describe "Html.Event custom decoders"
        [ fuzz Fuzz.string "targetValue" <|
            \value ->
                testDecoder
                    (eventJson { value = value, checked = False, keyCode = 0 })
                    E.targetValue
                    value
        , fuzz Fuzz.bool "targetChecked" <|
            \checked ->
                testDecoder
                    (eventJson { value = "", checked = checked, keyCode = 0 })
                    E.targetChecked
                    checked
        , fuzz Fuzz.int "keyCode " <|
            \keyCode ->
                testDecoder
                    (eventJson { value = "", checked = False, keyCode = keyCode })
                    E.keyCode
                    keyCode
        ]
