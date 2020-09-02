module Test.Bytes exposing (..)

import Bitwise
import Bytes exposing (Bytes)
import Bytes.Decode as Decode
import Bytes.Encode as Encode
import Expect
import FromElmTest.Fuzz
import Fuzz exposing (Fuzzer)
import Test exposing (..)


endianFuzzer : Fuzzer Bytes.Endianness
endianFuzzer =
    Fuzz.oneOf
        [ Fuzz.constant Bytes.LE
        , Fuzz.constant Bytes.BE
        ]


messyFloatFuzzer : Fuzzer Float
messyFloatFuzzer =
    Fuzz.frequency
        [ ( 0.8, Fuzz.float )
        , ( 0.05, Fuzz.constant (0 / 0) )
        , ( 0.05, Fuzz.constant (1 / 0) )
        , ( 0.05, Fuzz.constant (-1 / 0) )
        ]


encoderFuzzer : Fuzzer { name : String, width : Int, encoder : Encode.Encoder }
encoderFuzzer =
    Fuzz.oneOf
        [ -- signed ints
          Fuzz.map
            (\i ->
                { name = "signedInt8"
                , width = 1
                , encoder = Encode.signedInt8 i
                }
            )
            Fuzz.int
        , Fuzz.map2
            (\i en ->
                { name = "signedInt16"
                , width = 2
                , encoder = Encode.signedInt16 en i
                }
            )
            Fuzz.int
            endianFuzzer
        , Fuzz.map2
            (\i en ->
                { name = "signedInt32"
                , width = 4
                , encoder = Encode.signedInt32 en i
                }
            )
            Fuzz.int
            endianFuzzer
        , -- unsigned ints
          Fuzz.map
            (\i ->
                { name = "unsignedInt8"
                , width = 1
                , encoder = Encode.unsignedInt8 i
                }
            )
            Fuzz.int
        , Fuzz.map2
            (\i en ->
                { name = "unsignedInt16"
                , width = 2
                , encoder = Encode.unsignedInt16 en i
                }
            )
            Fuzz.int
            endianFuzzer
        , Fuzz.map2
            (\i en ->
                { name = "unsignedInt32"
                , width = 4
                , encoder = Encode.unsignedInt32 en i
                }
            )
            Fuzz.int
            endianFuzzer
        , -- floats
          Fuzz.map2
            (\f en ->
                { name = "float32"
                , width = 4
                , encoder = Encode.float32 en f
                }
            )
            messyFloatFuzzer
            endianFuzzer
        , Fuzz.map2
            (\f en ->
                { name = "float64"
                , width = 8
                , encoder = Encode.float64 en f
                }
            )
            messyFloatFuzzer
            endianFuzzer
        , -- string
          Fuzz.map
            (\s ->
                { name = "string"
                , width = Encode.getStringWidth s
                , encoder = Encode.string s
                }
            )
            FromElmTest.Fuzz.string
        , -- bytes
          Fuzz.map
            (\b ->
                { name = "bytes"
                , width = Bytes.width b
                , encoder = Encode.bytes b
                }
            )
            bytesFuzzer
        ]


encoderSequenceFuzzer : Fuzzer { names : List String, width : Int, encoder : Encode.Encoder }
encoderSequenceFuzzer =
    let
        maybeEncoder =
            Fuzz.maybe encoderFuzzer
    in
    Fuzz.list encoderFuzzer
        |> Fuzz.map
            (\encoders ->
                { names = List.map .name encoders
                , width = encoders |> List.map .width |> List.sum
                , encoder =
                    encoders |> List.map .encoder |> Encode.sequence
                }
            )


codecFuzzer : Fuzzer { name : String, width : Int, roundTrip : Bytes -> Maybe Bytes }
codecFuzzer =
    let
        intFuzzers =
            Fuzz.oneOf
                [ -- signed ints
                  Fuzz.constant
                    { name = "signedInt8"
                    , width = 1
                    , enc = Encode.signedInt8
                    , dec = Decode.signedInt8
                    }
                , Fuzz.map
                    (\en ->
                        { name = "signedInt16"
                        , width = 2
                        , enc = Encode.signedInt16 en
                        , dec = Decode.signedInt16 en
                        }
                    )
                    endianFuzzer
                , Fuzz.map
                    (\en ->
                        { name = "signedInt32"
                        , width = 4
                        , enc = Encode.signedInt32 en
                        , dec = Decode.signedInt32 en
                        }
                    )
                    endianFuzzer

                -- unsigned ints
                , Fuzz.constant
                    { name = "unsignedInt8"
                    , width = 1
                    , enc = Encode.unsignedInt8
                    , dec = Decode.unsignedInt8
                    }
                , Fuzz.map
                    (\en ->
                        { name = "unsignedInt16"
                        , width = 2
                        , enc = Encode.unsignedInt16 en
                        , dec = Decode.unsignedInt16 en
                        }
                    )
                    endianFuzzer
                , Fuzz.map
                    (\en ->
                        { name = "unsignedInt32"
                        , width = 4
                        , enc = Encode.unsignedInt32 en
                        , dec = Decode.unsignedInt32 en
                        }
                    )
                    endianFuzzer
                ]

        floatFuzzer =
            Fuzz.oneOf
                [ Fuzz.map
                    (\en ->
                        { name = "float64"
                        , width = 8
                        , enc = Encode.float64 en
                        , dec = Decode.float64 en
                        }
                    )
                    endianFuzzer
                ]

        tagger :
            { name : String
            , width : Int
            , enc : a -> Encode.Encoder
            , dec : Decode.Decoder a
            }
            -> { name : String, width : Int, roundTrip : Bytes -> Maybe Bytes }
        tagger { name, width, enc, dec } =
            { name = name
            , width = width
            , roundTrip =
                Decode.decode dec
                    >> Maybe.map (\i -> Encode.encode (enc i))
            }
    in
    Fuzz.oneOf
        [ intFuzzers
            |> Fuzz.map tagger
        , floatFuzzer
            |> Fuzz.map tagger
        ]


bytesFuzzer : Fuzzer Bytes
bytesFuzzer =
    Fuzz.list (Fuzz.intRange 0 255 |> Fuzz.map Encode.unsignedInt8)
        |> Fuzz.map (Encode.sequence >> Encode.encode)


{-| Produces unicode.

See <https://github.com/elm-explorations/test/pull/92>

-}
stringFuzzer : Fuzzer String
stringFuzzer =
    FromElmTest.Fuzz.string


zeroFill : Int -> Bytes -> Bytes
zeroFill n bytes =
    let
        width =
            Bytes.width bytes
    in
    if n == width then
        bytes

    else
        case Decode.decode (Decode.bytes n) bytes of
            Just newBytes ->
                newBytes

            Nothing ->
                -- This is the case if `n > width`.
                Encode.encode
                    (Encode.sequence
                        (Encode.bytes bytes :: List.repeat (n - width) (Encode.unsignedInt8 0))
                    )


expect32bitNan : Bytes -> Bytes.Endianness -> Expect.Expectation
expect32bitNan bytes en =
    case Decode.decode (Decode.unsignedInt32 en) bytes of
        Just bits ->
            let
                nanMask =
                    0x7F800000

                payloadMask =
                    0x007FFFFF
            in
            Expect.all
                [ Bitwise.and nanMask
                    >> Expect.equal nanMask
                , Bitwise.and payloadMask
                    >> Expect.notEqual 0
                ]
                bits

        Nothing ->
            Expect.fail "bug: cannot convert bytes to unsignedInt32"



-- TESTS


roundTripTests : Test
roundTripTests =
    describe "round trip"
        [ fuzz bytesFuzzer "bytes (encoding)" <|
            \bytes ->
                bytes
                    |> Encode.bytes
                    |> Encode.encode
                    |> Expect.equal bytes
        , fuzz bytesFuzzer "bytes (decoding)" <|
            \bytes ->
                bytes
                    |> Decode.decode (Decode.bytes (Bytes.width bytes))
                    |> Expect.equal (Just bytes)
        , fuzz2 bytesFuzzer codecFuzzer "simple" <|
            \bytes_ { width, roundTrip } ->
                let
                    bytes =
                        zeroFill width bytes_
                in
                roundTrip bytes
                    |> Expect.equal (Just bytes)
        , fuzz2 endianFuzzer bytesFuzzer "float32" <|
            \en bytes_ ->
                let
                    bytes =
                        zeroFill 4 bytes_
                in
                case
                    Decode.decode (Decode.float32 en) bytes
                of
                    Just float ->
                        if isNaN float then
                            expect32bitNan bytes en

                        else
                            Encode.float32 en float
                                |> Encode.encode
                                |> Expect.equal bytes

                    Nothing ->
                        Expect.fail "bug: cannot convert bytes to float32"
        , fuzz bytesFuzzer "strings from bytes" <|
            \bytes ->
                let
                    width =
                        Bytes.width bytes
                in
                case
                    Decode.decode (Decode.string width) bytes
                        |> Maybe.map (Encode.string >> Encode.encode)
                of
                    Just newBytes ->
                        newBytes |> Expect.equal bytes

                    Nothing ->
                        Expect.pass
        , fuzz FromElmTest.Fuzz.string "utf8 strings" <|
            \str ->
                let
                    width =
                        Encode.getStringWidth str
                in
                case
                    str
                        |> Encode.string
                        |> Encode.encode
                        |> Decode.decode (Decode.string width)
                of
                    Just newStr ->
                        newStr |> Expect.equal str

                    Nothing ->
                        Expect.fail "String did not encode into utf8 bytes"
        ]


equalityTests : Test
equalityTests =
    describe "equality"
        [ test "not equal" <|
            \() ->
                let
                    lhs =
                        Encode.encode
                            (Encode.sequence [ Encode.unsignedInt8 0xC0, Encode.unsignedInt8 0 ])

                    rhs =
                        Encode.encode
                            (Encode.sequence [ Encode.unsignedInt8 0 ])
                in
                lhs
                    |> Expect.notEqual rhs
        ]


lengthTests : Test
lengthTests =
    describe "Length tests"
        [ describe "ints"
            [ fuzz Fuzz.int "signedInt8" <|
                \i ->
                    Encode.signedInt8 i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 1
            , fuzz2 endianFuzzer Fuzz.int "signedInt16" <|
                \e i ->
                    Encode.signedInt16 e i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 2
            , fuzz2 endianFuzzer Fuzz.int "signedInt32" <|
                \e i ->
                    Encode.signedInt32 e i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 4
            , fuzz Fuzz.int "unsignedInt8" <|
                \i ->
                    Encode.unsignedInt8 i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 1
            , fuzz2 endianFuzzer Fuzz.int "unsignedInt16" <|
                \e i ->
                    Encode.unsignedInt16 e i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 2
            , fuzz2 endianFuzzer Fuzz.int "unsignedInt32" <|
                \e i ->
                    Encode.unsignedInt32 e i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 4
            ]
        , describe "floats"
            [ fuzz2 endianFuzzer messyFloatFuzzer "float32" <|
                \e i ->
                    Encode.float32 e i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 4
            , fuzz2 endianFuzzer messyFloatFuzzer "float64" <|
                \e i ->
                    Encode.float64 e i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 8
            ]
        , describe "strings"
            [ fuzz bytesFuzzer "from bytes" <|
                \bytes ->
                    let
                        width =
                            Bytes.width bytes
                    in
                    case
                        Decode.decode (Decode.string width) bytes
                            |> Maybe.map Encode.getStringWidth
                    of
                        Just newWidth ->
                            newWidth |> Expect.equal width

                        Nothing ->
                            Expect.pass
            , fuzz FromElmTest.Fuzz.string "valid unicode" <|
                \str ->
                    Encode.encode (Encode.string str)
                        |> Bytes.width
                        |> Expect.equal (Encode.getStringWidth str)
            ]
        , describe "random encoder"
            [ fuzz encoderFuzzer "single" <|
                \{ width, encoder } ->
                    encoder
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal width
            , fuzz encoderSequenceFuzzer "sequence" <|
                \{ width, encoder } ->
                    encoder
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal width
            ]
        ]
