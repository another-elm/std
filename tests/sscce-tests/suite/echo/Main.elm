module Main exposing (main)

import Platform
import Util.Cmds
import Util.Subs

type Msg = Read String

main : Platform.Program () () Msg
main  =
    Platform.worker
        { init = \() -> ( (), Cmd.none )
        , update = update
        , subscriptions = \() -> Util.Subs.read Read
        }


update : Msg -> () -> ((), Cmd Msg)
update (Read s) () =
    ( (), Util.Cmds.write s )

