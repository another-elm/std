module Main exposing (main)

import Platform
import Util.Programs

g : Int -> Int
g =
    h

h : Int -> Int
h n =
  if n < 2 then 1 else g (n - 1)


toWrite : String
toWrite =
    String.fromInt (h 10)


main : Platform.Program () () ()
main =
    Util.Programs.print toWrite
