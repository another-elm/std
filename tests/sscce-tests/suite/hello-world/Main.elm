module Main exposing (main)

import Platform
import Util.Programs


main : Platform.Program () () ()
main =
    Util.Programs.print "Hello World!"
