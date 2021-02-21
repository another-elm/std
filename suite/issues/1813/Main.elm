module Main exposing (main)

import Platform
import Util.Programs


foo : List Int
foo =
    let
        loop n list =
            if n <= 0 then
                list

            else
                loop (n - 1) ((\() -> n) :: list)
    in
    List.map (\f -> f ()) <|
        loop 3 []


toWrite : String
toWrite =
    String.join " " (List.map String.fromInt foo)


main : Platform.Program () () ()
main =
    Util.Programs.print toWrite
