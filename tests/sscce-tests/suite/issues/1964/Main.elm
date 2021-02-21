module Main exposing (main)

import Platform
import Util.Programs


type Type a
    = TypeCtor (Type (Wrapper a))


type Wrapper a
    = Wrapper a


foo : Type a -> ()
foo (TypeCtor t) =
    foo t


main : Platform.Program () () ()
main =
    Util.Programs.noop
