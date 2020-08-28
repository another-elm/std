module Test.Bytes exposing (..)

import Bitwise
import Bytes exposing (Bytes)
import Bytes.Decode as Decode
import Bytes.Encode as Encode
import Expect
import FromElmTest.Fuzz
import Fuzz exposing (Fuzzer, intRange)
import Test exposing (..)
import Fuzz exposing (int)


endianFuzzer : Fuzzer Bytes.Endianness
endianFuzzer =
    Fuzz.oneOf
        [ Fuzz.constant Bytes.LE
        , Fuzz.constant Bytes.BE
        ]


codecFuzzer : Fuzzer ( String, Int, Bytes -> Maybe Bytes )
codecFuzzer =
    let
        intFuzzers =
            Fuzz.oneOf
                [ -- signed ints
                  Fuzz.constant ( "signedInt8", ( 1, Encode.signedInt8, Decode.signedInt8 ) )
                , Fuzz.map
                    (\en -> ( "signedInt16", ( 2, Encode.signedInt16 en, Decode.signedInt16 en ) ))
                    endianFuzzer
                , Fuzz.map
                    (\en -> ( "signedInt32", ( 4, Encode.signedInt32 en, Decode.signedInt32 en ) ))
                    endianFuzzer

                -- unsigned ints
                , Fuzz.constant ( "unsignedInt8", ( 1, Encode.unsignedInt8, Decode.unsignedInt8 ) )
                , Fuzz.map
                    (\en -> ( "unsignedInt16", ( 2, Encode.unsignedInt16 en, Decode.unsignedInt16 en ) ))
                    endianFuzzer
                , Fuzz.map
                    (\en -> ( "unsignedInt32", ( 4, Encode.unsignedInt32 en, Decode.unsignedInt32 en ) ))
                    endianFuzzer
                ]

        floatFuzzer =
            Fuzz.oneOf
                [ Fuzz.map
                    (\en -> ( "float64", ( 8, Encode.float64 en, Decode.float64 en ) ))
                    endianFuzzer
                ]

        tagger : ( String, ( Int, a -> Encode.Encoder, Decode.Decoder a ) ) -> ( String, Int, Bytes -> Maybe Bytes )
        tagger ( label, ( len, enc, dec ) ) =
            ( label
            , len
            , Decode.decode dec
                >> Maybe.map (\i -> Encode.encode (enc i))
            )
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
            \bytes_ ( _, n, roundTrip ) ->
                let
                    bytes =
                        zeroFill n bytes_
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
            [ fuzz2 endianFuzzer Fuzz.float "float32" <|
                \e i ->
                    Encode.float32 e i
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal 4
            , fuzz2 endianFuzzer Fuzz.float "float64" <|
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
        ]
