module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes
import Html.Events exposing (onClick)
import Html.Keyed
import Html.Lazy
import Markdown
import Svg
import Svg.Attributes
import Url


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , state : Int
    }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init () url key =
    ( { key = key
      , url = url
      , state = 0
      }
    , Cmd.none
    )


type Msg
    = NextState
    | UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | Log Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NextState ->
            ( { model | state = model.state + 1 }, Cmd.none )

        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )

        Log int ->
            let
                _ =
                    Debug.log "Log" int
            in
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Model -> Browser.Document Msg
view model =
    { title = "Application Title"
    , body =
        if False then
            [ text ("text " ++ String.fromInt model.state)
            , Html.button [ onClick NextState ] []
            ]

        else
            [ text ("text " ++ String.fromInt model.state)
            , div [ Html.Attributes.class "klass" ] [ text ("div: " ++ String.fromInt model.state) ]
            , Html.Keyed.node "sektion" [] [ ( "key1", text ("Nyckel: " ++ String.fromInt model.state) ), ( "key2", div [] [ text "key2" ] ) ]
            , Html.Lazy.lazy viewNum (model.state // 2)
            , map Log (Html.button [ onClick 1, onClick 1 |> Html.Attributes.map ((+) 1) ] [ text ("karta: " ++ String.fromInt model.state) ])
            , Markdown.toHtml [ Html.Attributes.id "my-id" ] ("nedåt: " ++ String.fromInt model.state)
            , Svg.svg [ Svg.Attributes.xmlLang "en-US" ] []
            , Html.a
                (if model.state |> modBy 2 |> (==) 0 then
                    []

                 else
                    [ Html.Attributes.href "#foo" ]
                )
                [ Html.text "Link" ]
            , Html.node "custom-element"
                [ Html.Attributes.class "yoyo" ]
                [ Html.text ("Text from Elm. " ++ String.fromInt model.state) ]
            , Html.button
                [ onClick NextState
                , Html.Attributes.type_ "button"
                , Html.Attributes.style "outline" "1px solid red"
                , Html.Attributes.tabindex 1
                ]
                [ text "Nästa" ]
            ]
                |> (\list ->
                        case model.state of
                            0 ->
                                list

                            1 ->
                                list

                            2 ->
                                List.reverse list

                            3 ->
                                List.drop 2 list

                            _ ->
                                list
                   )
    }


viewNum : Int -> Html msg
viewNum n =
    let
        _ =
            Debug.log "viewNum" n
    in
    Html.text ("Lat (varannan): " ++ String.fromInt n)
