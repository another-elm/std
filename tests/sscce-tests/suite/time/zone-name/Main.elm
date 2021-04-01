module Main exposing (main)

import Platform
import Task
import Time
import Util.Cmds


type Msg
    = Init Time.ZoneName


init : ( (), Cmd Msg )
init =
    ( ()
    , Task.perform Init Time.getZoneName
    )


update : Msg -> () -> ( (), Cmd Msg )
update msg () =
    case msg of
        Init z ->
            ( ()
            , if z == Time.Name "Asia/Bahrain" then
                Util.Cmds.write "good - zone is as expected"

              else
                Util.Cmds.error [ "Debug.toString z" ]
            )


main : Platform.Program () () Msg
main =
    Platform.worker
        { init = \() -> init
        , update = update
        , subscriptions = \_ -> Sub.none
        }
