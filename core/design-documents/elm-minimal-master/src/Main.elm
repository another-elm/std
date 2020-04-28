module Main exposing (..)

import Platform


arithmeticMean : Float -> Float -> Float
arithmeticMean a b =
    (a + b) / 2


geometricMean : Float -> Float -> Float
geometricMean a b =
    sqrt (a * b)


compositionExample : (Float -> Float)
compositionExample =
    arithmeticMean 6
        >> geometricMean 20


main =
    let
        m = compositionExample 4
    in

    Platform.worker
        { init = \() -> (m, Cmd.none)
        , update = \model _ -> (model, Cmd.none)
        , subscriptions = \_ -> Sub.none
        }
