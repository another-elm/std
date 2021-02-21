module Main exposing (main)

import Platform
import Task
import Time
import Util.Cmds


type Model
    = Loading
    | Loaded
    | End


type Msg
    = Load
    | Tick


main : Platform.Program () Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, Task.perform (\x -> x) (Task.succeed Load) )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg _ =
    case msg of
        Load ->
            ( Loaded, Util.Cmds.write "load" )

        Tick ->
            ( End, Util.Cmds.write "tick" )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Loading ->
            Sub.none

        Loaded ->
            Time.every 100 (\_ -> Tick)

        End ->
            Sub.none
