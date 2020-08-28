module FromElmTest.Fuzz exposing (string)

import Array exposing (Array)
import Char
import FromElmTest.Fuzz.Internal as Internal exposing (frequencyList)
import FromElmTest.MicroRandomExtra as Random
import Fuzz
import Random exposing (Generator)
import Shrink


asciiCharGenerator : Generator Char
asciiCharGenerator =
    Random.map Char.fromCode (Random.int 32 126)


unicodeCharGeneratorFrequencies : ( ( Float, Generator Char ), List ( Float, Generator Char ) )
unicodeCharGeneratorFrequencies =
    let
        ascii =
            asciiCharGenerator

        whitespace =
            Random.sample [ ' ', '\t', '\n' ] |> Random.map (Maybe.withDefault ' ')

        tilde =
            '̃'

        circumflex =
            '̂'

        diaeresis =
            '̈'

        combiningDiacriticalMarks =
            Random.sample [ circumflex, tilde, diaeresis ] |> Random.map (Maybe.withDefault circumflex)

        emoji =
            Random.sample [ '🌈', '❤', '🔥' ] |> Random.map (Maybe.withDefault '❤')
    in
    ( ( 4, ascii )
    , [ ( 1, whitespace )
      , ( 1, combiningDiacriticalMarks )
      , ( 1, emoji )
      ]
    )


{-| Generates random printable unicode strings of up to 1000 characters.

Shorter strings are more common, especially the empty string.

-}
string : Fuzz.Fuzzer String
string =
    let
        ( firstFreq, restFreqs ) =
            unicodeCharGeneratorFrequencies

        lengthGenerator =
            Random.frequency
                ( 3, Random.int 1 10 )
                [ ( 0.2, Random.constant 0 )
                , ( 1, Random.int 11 50 )
                , ( 1, Random.int 50 1000 )
                ]

        unicodeGenerator =
            frequencyList lengthGenerator firstFreq restFreqs
                |> Random.map String.fromList
    in
    Fuzz.custom unicodeGenerator Shrink.string
