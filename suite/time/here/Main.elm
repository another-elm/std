module Main exposing (main)

import Platform
import Task
import Time
import Util.Cmds


type Msg
    = Init Time.Zone


init : ( (), Cmd Msg )
init =
    ( ()
    , Task.perform Init Time.here
    )


update : Msg -> () -> ( (), Cmd Msg )
update msg () =
    case msg of
        Init z ->
            ( ()
            , if z == Time.customZone (3*60) [] then
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
