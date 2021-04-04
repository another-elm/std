module Main exposing (main)

import Platform
import Util.Programs

f : { a : Int } -> Int
f {} =
    5

main : Platform.Program () () ()
main =
    Util.Programs.print "Hello World!"

