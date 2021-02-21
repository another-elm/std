module Main exposing (main)

{-| This is not how Cmd.map is designed to be used.
However, it should test some of the knarly bits of elm/core:Platform
-}

import Platform
import Task
import Util.Cmds


type Msg
    = Init Float
    | PrintMe String


init : ( (), Cmd Msg )
init =
    ( ()
    , Task.perform (\x -> x) (Task.succeed 7)
        |> Cmd.map (\i -> 1 / toFloat i)
        |> Cmd.map Init
    )


update : Msg -> () -> ( (), Cmd Msg )
update msg () =
    case msg of
        Init f ->
            ( ()
            , Task.perform String.fromFloat (Task.succeed f)
                |> Cmd.map (\s -> PrintMe (String.left 5 s))
            )

        PrintMe s ->
            ( ()
            , Util.Cmds.write s
            )


main : Platform.Program () () Msg
main =
    Platform.worker
        { init = \() -> init
        , update = update
        , subscriptions = \_ -> Sub.none
        }
