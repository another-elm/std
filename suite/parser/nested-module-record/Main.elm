module Main exposing (main)

import Platform
import Util.Programs
import Nested.Module


toWrite : String
toWrite =
    String.fromInt Nested.Module.record.theAnswer


main : Platform.Program () () ()
main =
    Util.Programs.print toWrite
