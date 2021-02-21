module Main exposing (main)


import Platform
import Process
import Task
import Util.Cmds


type Msg
    = Init


init : ( (), Cmd Msg )
init =
    ( ()
    , Task.perform (\() -> Init) (Process.sleep 1)
    )


update : Msg -> () -> ( (), Cmd Msg )
update msg () =
    case msg of
        Init ->
            ( ()
            , Util.Cmds.write "done"
            )


main : Platform.Program () () Msg
main =
    Platform.worker
        { init = \() -> init
        , update = update
        , subscriptions = \_ -> Sub.none
        }
