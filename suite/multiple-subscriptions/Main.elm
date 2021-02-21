port module Main exposing (main)

import Platform
import Util.Cmds
import Util.Subs


type Msg
    = Read String
    | DifferentRead String


port differentRead : (String -> msg) -> Sub msg


main : Platform.Program () () Msg
main =
    Platform.worker
        { init = \() -> ( (), Cmd.none )
        , update = update
        , subscriptions =
            \() ->
                Sub.batch
                    [ Util.Subs.read Read
                    , differentRead DifferentRead
                    ]
        }


update : Msg -> () -> ( (), Cmd Msg )
update msg () =
    ( ()
    , case msg of
        Read _ ->
            Util.Cmds.write "1"

        DifferentRead _ ->
            Util.Cmds.write "2"
    )
