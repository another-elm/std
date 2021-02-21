module Main exposing (main)

import Platform
import Util.Programs


fromMaybe : ((a -> Maybe b) -> c) -> ((a -> b) -> c)
fromMaybe f =
    f << (<<) Just


toWrite : String
toWrite =
    fromMaybe
        (\makeMaybeList ->
            let
                list =
                    makeMaybeList 7
                        |> Maybe.withDefault []
            in
            List.length list
                |> String.fromInt
        )
        (\x -> [ x, x ])


main : Platform.Program () () ()
main =
    Util.Programs.print toWrite
