port module AllHtmlEvents exposing (main)

import Browser
import Html
import Html.Attributes
import Html.Events
import Task


type Msg
    = Click
    | DoubleClick
    | MouseDown
    | MouseUp
    | MouseEnter
    | MouseLeave
    | MouseOver
    | MouseOut
    | Input String
    | Check Bool
    | Submit
    | Blur
    | Focus


port onClick : () -> Cmd never


port onDoubleClick : () -> Cmd never


port onMouseDown : () -> Cmd never


port onMouseUp : () -> Cmd never


port onMouseEnter : () -> Cmd never


port onMouseLeave : () -> Cmd never


port onMouseOver : () -> Cmd never


port onMouseOut : () -> Cmd never



-- Forms


port onInput : String -> Cmd never


port onCheck : Bool -> Cmd never


port onSubmit : () -> Cmd never



-- Focus


port onBlur : () -> Cmd never


port onFocus : () -> Cmd never


main : Program () () Msg
main =
    Browser.element
        { init = \() -> ( (), Cmd.none )
        , update = update
        , subscriptions = \() -> Sub.none
        , view = \() -> view
        }


update : Msg -> () -> ( (), Cmd Msg )
update msg () =
    case msg of
        Click ->
            ( (), onClick () )

        DoubleClick ->
            ( (), onDoubleClick () )

        MouseDown ->
            ( (), onMouseDown () )

        MouseUp ->
            ( (), onMouseUp () )

        MouseEnter ->
            ( (), onMouseEnter () )

        MouseLeave ->
            ( (), onMouseLeave () )

        MouseOver ->
            ( (), onMouseOver () )

        MouseOut ->
            ( (), onMouseOut () )

        Input s ->
            ( (), onInput s )

        Check b ->
            ( (), onCheck b )

        Submit ->
            ( (), onSubmit () )

        Blur ->
            ( (), onBlur () )

        Focus ->
            ( (), onFocus () )


view : Html.Html Msg
view =
    Html.div
        []
        [ -- Mouse
          Html.div
            [ Html.Attributes.id "click-me"
            , Html.Events.onClick Click
            ]
            []
        , Html.div
            [ Html.Attributes.id "double-click-me"
            , Html.Events.onDoubleClick DoubleClick
            ]
            []
        , Html.div
            [ Html.Attributes.id "mousedown-me"
            , Html.Events.onMouseDown MouseDown
            ]
            []
        , Html.div
            [ Html.Attributes.id "mouseup-me"
            , Html.Events.onMouseUp MouseUp
            ]
            []
        , Html.div
            [ Html.Attributes.id "mouseenter-me"
            , Html.Events.onMouseEnter MouseEnter
            ]
            []
        , Html.div
            [ Html.Attributes.id "mouseleave-me"
            , Html.Events.onMouseLeave MouseLeave
            ]
            []
        , Html.div
            [ Html.Attributes.id "mouseover-me"
            , Html.Events.onMouseOver MouseOver
            ]
            []
        , Html.div
            [ Html.Attributes.id "mouseout-me"
            , Html.Events.onMouseOut MouseOut
            ]
            []
        , Html.div
            [ Html.Attributes.id "mouseout-me"
            , Html.Events.onMouseOut MouseOut
            ]
            []

        -- Forms
        , Html.input
            [ Html.Attributes.id "form-input-me"
            , Html.Attributes.value "value of input form"
            , Html.Events.onInput Input
            ]
            []
        , Html.input
            [ Html.Attributes.id "form-check-me"
            , Html.Attributes.value "value of input form"
            , Html.Events.onCheck Check
            ]
            []
        , Html.input
            [ Html.Attributes.id "form-submit-me"
            , Html.Events.onSubmit Submit
            ]
            []
        ]
