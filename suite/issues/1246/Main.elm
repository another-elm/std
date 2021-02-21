module Main exposing (main)

import Platform
import Util.Programs


toWrite : String
toWrite =
    String.fromInt 1000000000000000000000


main : Platform.Program () () ()
main =
    Util.Programs.print toWrite
