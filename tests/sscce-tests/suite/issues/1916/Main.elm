module Main exposing (main)

import Platform
import Util.Programs


type Value r
    = Value


-- type alias Bug r =
--     Value { r | field : () } -> ()

type alias Bug r =
    Value { r | field : () } -> ()


bug : Bug {}
bug Value =
    ()


main : Platform.Program () () ()
main =
    Util.Programs.noop
