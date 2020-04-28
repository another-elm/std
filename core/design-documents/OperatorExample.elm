module OperatorExample exposing (..)

import Platform


compositionExample : (Float -> Float -> Float)
compositionExample x =
    mean 6
        >> mean x


mean : Float -> Float -> Float
mean a b =
    (a + b) / 2


ident : Bool -> Bool
ident b =
    not (not b)


main =
    let
        m = compositionExample 21 4

        _ = ident True
    in

    Platform.worker
        { init = \() -> (m, Cmd.none)
        , update = \model _ -> (model, Cmd.none)
        , subscriptions = \_ -> Sub.none
        }
