module Main exposing (main)

import Platform
import Util.Programs
import Util.Subs


type Model
    = World


main : Platform.Program () Model Never
main  =
    Platform.worker
        { init = \() -> ( Debug.log "hello" World, Cmd.none )
        , update = \_ m -> ( m, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }



