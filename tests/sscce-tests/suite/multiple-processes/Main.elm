module Main exposing (main)

import Platform
import Process
import Task exposing (Task)
import Util.Cmds


type Msg
    = Init
    | Done


createProcesses : Int -> Task x ()
createProcesses n =
    List.range 1 n
        |> List.map toFloat
        |> List.map (\i -> Task.andThen Process.sleep (Task.succeed i))
        |> List.map Process.spawn
        |> Task.sequence
        |> Task.map (\_ -> ())


init : ( (), Cmd Msg )
init =
    ( ()
    , createProcesses 10
        |> Task.perform (\() -> Init)
    )


update : Msg -> () -> ( (), Cmd Msg )
update msg counter =
    case msg of
        Init ->
            ( ()
            , createProcesses 10
                |> Task.perform (\() -> Done)
            )

        Done ->
            ( (), Util.Cmds.write "done" )


main : Platform.Program () () Msg
main =
    Platform.worker
        { init = \() -> init
        , update = update
        , subscriptions = \_ -> Sub.none
        }
