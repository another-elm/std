module Main exposing (main)

import Platform
import Util.Programs
import Util.Subs


main : Platform.Program () () Never
main  =
    let
        _ = Debug.log "half-baked"
    in
    Util.Programs.noop



