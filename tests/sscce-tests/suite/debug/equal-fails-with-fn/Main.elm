module Main exposing (main)

import Platform
import Util.Programs
import Util.Subs


a : List (a -> a)
a =
    [ \x -> x ]


main : Platform.Program () () Never
main  =
    let
        v =
            if a == a then
                "True"
            else
                "False"

    in
    Util.Programs.print v



