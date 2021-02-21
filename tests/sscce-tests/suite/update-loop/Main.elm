module Main exposing (main)

import Platform
import Task
import Util.Cmds


init : ( Int, Cmd () )
init =
    ( 0
    , Task.perform (\x -> x) (Task.succeed ())
    )


update : a -> Int -> ( Int, Cmd () )
update _ counter =
    ( counter + 1
    , if counter > 10 then
        Cmd.none

      else
        Cmd.batch
            [ Util.Cmds.write (String.fromInt counter)
            , Task.perform (\x -> x) (Task.succeed ())
            ]
    )


main : Platform.Program () Int ()
main =
    Platform.worker
        { init = \() -> init
        , update = update
        , subscriptions = \_ -> Sub.none
        }
