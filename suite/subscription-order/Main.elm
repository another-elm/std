module Main exposing (main)

{-| SSCCE based on <https://github.com/elm/compiler/issues/1776>
-}

import Task
import Time exposing (Posix, Zone)
import Util.Cmds


type Model
    = Loading
    | HasZone Zone
    | Done


type Msg
    = NewZone Zone
    | Tick Posix


main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, Task.perform NewZone Time.here )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg _ =
    case msg of
        NewZone zone ->
            ( HasZone zone, Util.Cmds.write "got zone" )

        Tick _ ->
            ( Done, Util.Cmds.write "got tick" )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Loading ->
            Sub.none

        HasZone _ ->
            Time.every 100 Tick

        Done ->
            Sub.none

