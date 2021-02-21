module Main exposing (main)

import Platform
import Random
import Util.Cmds
import Util.Subs


type Msg
    = Rand Int


randomCmd : Cmd Msg
randomCmd =
    Random.generate Rand (Random.int 0 1000)


main : Platform.Program () Int Msg
main =
    Platform.worker
        { init = \() -> ( 0, randomCmd )
        , update = update
        , subscriptions = \_ -> Sub.none
        }


update : Msg -> Int -> ( Int, Cmd Msg )
update (Rand i) count =
    ( count + 1
    , if count < 10 then
        Cmd.batch
            [ Util.Cmds.write (String.fromInt i)
            , randomCmd
            ]

      else
        Cmd.none
    )
