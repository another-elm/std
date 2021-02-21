module Main exposing (main, test2)

import Module1
import Platform
import Util.Programs


test2 : ()
test2 =
    Module1.test1


main : Platform.Program () () ()
main =
    Util.Programs.noop
