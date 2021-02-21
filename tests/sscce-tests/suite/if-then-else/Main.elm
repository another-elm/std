module Main exposing (main)

import Platform
import Util.Programs
import Util.Cmds
import Task


str : Bool -> String
str b =
    if b then
        "first"
    else
        "second"


initialCmd =
    Cmd.batch
        [ Util.Cmds.write (str True)
        , Task.perform (\x -> x) (Task.succeed ())
        ]


main : Platform.Program () () ()
main =
    Platform.worker
        { init = \() -> ( (), initialCmd )
        , update = \() () -> ( (), Util.Cmds.write (str False))
        , subscriptions = \() -> Sub.none
        }
