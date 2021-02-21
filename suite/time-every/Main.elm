module Main exposing (main)

import Platform
import Time
import Util.Cmds


type Msg
    = Init
    | Time1
    | Time2


type Item
    = One
    | Two
    | Three
    | Four


type alias Model =
    ( Item, List Item )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ( item1, items ) =
    case msg of
        Init ->
            ( ( Two, item1 :: items )
            , Cmd.none
            )

        Time1 ->
            ( ( Three, item1 :: items )
            , Util.Cmds.write "1"
            )

        Time2 ->
            ( ( Four, item1 :: items )
            , Util.Cmds.write "2"
            )


subscriptions : Model -> Sub Msg
subscriptions ( item, _ ) =
    let
        subs =
            Sub.batch
                [ Time.every 30 (\_ -> Time1)
                , Time.every 100 (\_ -> Time2)
                ]
    in
    case item of
        -- Get app in sync with 300ms intervals
        One ->
            Time.every 300 (\_ -> Init)

        Two ->
            subs

        Three ->
            subs

        Four ->
            Sub.none


main : Platform.Program () Model Msg
main =
    Platform.worker
        { init = \() -> ( ( One, [] ), Cmd.none )
        , update = update
        , subscriptions = subscriptions
        }
