module Test.Bytes exposing (..)

import Bitwise
import Bytes exposing (Bytes)
import Bytes.Decode as Decode
import Bytes.Encode as Encode
import Expect
import FromElmTest.Fuzz
import Fuzz exposing (Fuzzer)
import Hex
import Test exposing (..)


type Hash
    = Hash String


startingHash : Hash
startingHash =
    Hash ""


combineHash : Hash -> Hash -> Hash
combineHash (Hash a) (Hash b) =
    Hash (a ++ b)


hashString : String -> Hash
hashString s =
    Hash ("__string " ++ s)


hashInt : Int -> Hash
hashInt i =
    Hash ("__int" ++ String.fromInt i)


hashFloat : Float -> Hash
hashFloat f =
    Hash ("__float" ++ String.fromFloat f)


{-| Hash in such a way that the `float -> 32 bits -> float` conversion does not
change hash.
-}
hashFloat32 : Float -> Hash
hashFloat32 f =
    Hash
        ("__float32"
            ++ (if f < 0 then
                    "-"

                else
                    ""
               )
            ++ "2^"
            ++ (f |> logBase 2 |> round |> String.fromInt)
        )


hashBytes : Bytes -> Hash
hashBytes b =
    let
        width =
            Bytes.width b

        hex =
            Hex.toString
                >> String.padLeft 2 '0'

        listStep ( n, s ) =
            if n <= 0 then
                Decode.succeed (Decode.Done s)

            else
                Decode.map (\x -> Decode.Loop ( n - 1, s ++ hex x )) Decode.unsignedInt8
    in
    case
        Decode.decode
            (Decode.loop ( width, "" ) listStep)
            b
    of
        Just s ->
            Hash ("__bytes0x" ++ s)

        Nothing ->
            Hash "__WARNING_ERROR_BAD_THING_HAS_HAPPENED"


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


codecFuzzer :
    Fuzzer
        { name : String
        , width : Int
        , hash : Hash
        , encoder : Encode.Encoder
        , decoder : Decode.Decoder Hash
        }
codecFuzzer =
    Fuzz.oneOf
        [ -- signed ints
          Fuzz.map
            (\i ->
                { name = "signedInt8"
                , width = 1
                , hash = hashInt i
                , encoder = Encode.signedInt8 i
                , decoder =
                    Decode.signedInt8
                        |> Decode.map (\ii -> hashInt ii)
                }
            )
            (Fuzz.intRange (0 - 0x80) 0x7F)
        , Fuzz.map2
            (\i en ->
                { name = "signedInt16"
                , width = 2
                , hash = hashInt i
                , encoder = Encode.signedInt16 en i
                , decoder =
                    Decode.signedInt16 en
                        |> Decode.map (\ii -> hashInt ii)
                }
            )
            (Fuzz.intRange (0 - 0x8000) 0x7FFF)
            endianFuzzer
        , Fuzz.map2
            (\i en ->
                { name = "signedInt32"
                , width = 4
                , hash = hashInt i
                , encoder = Encode.signedInt32 en i
                , decoder =
                    Decode.signedInt32 en
                        |> Decode.map (\ii -> hashInt ii)
                }
            )
            (Fuzz.intRange (0 - 0x80000000) 0x7FFFFFFF)
            endianFuzzer
        , -- unsigned ints
          Fuzz.map
            (\i ->
                { name = "unsignedInt8"
                , width = 1
                , hash = hashInt i
                , encoder = Encode.unsignedInt8 i
                , decoder =
                    Decode.unsignedInt8
                        |> Decode.map (\ii -> hashInt ii)
                }
            )
            (Fuzz.intRange 0 0xFF)
        , Fuzz.map2
            (\i en ->
                { name = "unsignedInt16"
                , width = 2
                , hash = hashInt i
                , encoder = Encode.unsignedInt16 en i
                , decoder =
                    Decode.unsignedInt16 en
                        |> Decode.map (\ii -> hashInt ii)
                }
            )
            (Fuzz.intRange 0 0xFFFF)
            endianFuzzer
        , Fuzz.map2
            (\i en ->
                { name = "unsignedInt32"
                , width = 4
                , hash = hashInt i
                , encoder = Encode.unsignedInt32 en i
                , decoder =
                    Decode.unsignedInt32 en
                        |> Decode.map (\ii -> hashInt ii)
                }
            )
            (Fuzz.intRange 0 0xFFFFFFFF)
            endianFuzzer
        , -- floats
          Fuzz.map2
            (\f en ->
                { name = "float32"
                , width = 4
                , hash = hashFloat32 f
                , encoder = Encode.float32 en f
                , decoder =
                    Decode.float32 en
                        |> Decode.map (\ff -> hashFloat32 ff)
                }
            )
            messyFloatFuzzer
            endianFuzzer
        , Fuzz.map2
            (\f en ->
                { name = "float64"
                , width = 8
                , hash = hashFloat f
                , encoder = Encode.float64 en f
                , decoder =
                    Decode.float64 en
                        |> Decode.map (\ff -> hashFloat ff)
                }
            )
            messyFloatFuzzer
            endianFuzzer
        , -- string
          Fuzz.map
            (\s ->
                let
                    width =
                        Encode.getStringWidth s
                in
                { name = "string"
                , width = width
                , hash = hashString s
                , encoder = Encode.string s
                , decoder =
                    Decode.string width
                        |> Decode.map (\ss -> hashString ss)
                }
            )
            FromElmTest.Fuzz.string
        , -- bytes
          Fuzz.map
            (\b ->
                let
                    width =
                        Bytes.width b
                in
                { name = "bytes"
                , width = width
                , hash = hashBytes b
                , encoder = Encode.bytes b
                , decoder =
                    Decode.bytes width
                        |> Decode.map (\bb -> hashBytes bb)
                }
            )
            bytesFuzzer
        ]


type Tree
    = Leaf
    | Branch Tree Tree


tree : Int -> Fuzzer Tree
tree i =
    if i <= 0 then
        Fuzz.constant Leaf

    else
        Fuzz.frequency
            [ ( 1, Fuzz.constant Leaf )
            , ( 2, Fuzz.map2 Branch (tree (i - 1)) (tree (i - 1)) )
            ]


codecSequenceFuzzer :
    Fuzzer
        { names : List String
        , width : Int
        , hash : Hash
        , encoder : Encode.Encoder
        , decoder : Decode.Decoder Hash
        }
codecSequenceFuzzer =
    codecSequenceFuzzerDepth 3


codecSequenceFuzzerDepth :
    Int
    ->
        Fuzzer
            { names : List String
            , width : Int
            , hash : Hash
            , encoder : Encode.Encoder
            , decoder : Decode.Decoder Hash
            }
codecSequenceFuzzerDepth maxDepth =
    let
        singleCodec =
            codecFuzzer
                |> Fuzz.map
                    (\codec ->
                        { names = List.singleton codec.name
                        , width = codec.width
                        , hash = codec.hash
                        , encoder = codec.encoder
                        , decoder = codec.decoder
                        }
                    )
    in
    Fuzz.list
        (if maxDepth <= 0 then
            singleCodec

         else
            Fuzz.frequency
                [ ( 9, singleCodec )
                , ( 1, codecSequenceFuzzerDepth (maxDepth - 1) )
                ]
        )
        |> Fuzz.map
            (\codecs ->
                { names = List.concatMap .names codecs
                , width = codecs |> List.map .width |> List.sum
                , hash = List.foldl (\{ hash } acc -> combineHash acc hash) startingHash codecs
                , encoder =
                    codecs |> List.map .encoder |> Encode.sequence
                , decoder =
                    Decode.loop
                        ( codecs, startingHash )
                        (\( codecsLeft, acc ) ->
                            case codecsLeft of
                                [] ->
                                    Decode.succeed (Decode.Done acc)

                                { decoder } :: rest ->
                                    Decode.map
                                        (\newHash -> Decode.Loop ( rest, combineHash acc newHash ))
                                        decoder
                        )
                }
            )


codecFuzzer2 : Fuzzer { name : String, width : Int, roundTrip : Bytes -> Maybe Bytes }
codecFuzzer2 =
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
        [ describe "starting with bytes"
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
            , fuzz2 bytesFuzzer codecFuzzer2 "simple" <|
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
        , describe "starting with encoder"
            [ fuzz codecFuzzer "single" <|
                \{ hash, encoder, decoder } ->
                    Encode.encode encoder
                        |> Decode.decode decoder
                        |> Expect.equal (Just hash)
            , fuzz codecSequenceFuzzer "sequences" <|
                \{ hash, encoder, decoder } ->
                    Encode.encode encoder
                        |> Decode.decode decoder
                        |> Expect.equal (Just hash)
            ]
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
            [ fuzz codecFuzzer "single" <|
                \{ width, encoder } ->
                    encoder
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal width
            , fuzz codecSequenceFuzzer "sequence" <|
                \{ width, encoder } ->
                    encoder
                        |> Encode.encode
                        |> Bytes.width
                        |> Expect.equal width
            ]
        ]
