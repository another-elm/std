module Test.Html.Event exposing
    ( Event, simulate, expect, toResult
    , custom, click, doubleClick, mouseDown, mouseUp, mouseEnter, mouseLeave, mouseOver, mouseOut, input, check, submit, blur, focus
    )

{-| This module lets you simulate events on `Html` values and expect that
they result in certain `Msg` values being sent to `update`.


## Simulating Events

@docs Event, simulate, expect, toResult


## Event Builders

@docs custom, click, doubleClick, mouseDown, mouseUp, mouseEnter, mouseLeave, mouseOver, mouseOut, input, check, submit, blur, focus

-}

import Dict
import Expect exposing (Expectation)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Test.Html.Internal.ElmHtml.InternalTypes exposing (ElmHtml(..), Tagger)
import Test.Html.Query as Query
import Test.Html.Query.Internal as QueryInternal
import Test.Internal as Internal
import VirtualDom


{-| A simulated event.

See [`simulate`](#simulate).

-}
type Event msg
    = Event ( String, Value ) (QueryInternal.Single msg)


{-| Simulate an event on a node.

    import Test.Html.Event as Event

    type Msg
        = Change String


    test "Input produces expected Msg" <|
        \() ->
            Html.input [ onInput Change ] [ ]
                |> Query.fromHtml
                |> Event.simulate (Event.input "cats")
                |> Event.expect (Change "cats")

-}
simulate : ( String, Value ) -> Query.Single msg -> Event msg
simulate =
    Event


{-| Passes if the given message is triggered by the simulated event.

    import Test.Html.Event as Event

    type Msg
        = Change String


    test "Input produces expected Msg" <|
        \() ->
            Html.input [ onInput Change ] [ ]
                |> Query.fromHtml
                |> Event.simulate (Event.input "cats")
                |> Event.expect (Change "cats")

-}
expect : msg -> Event msg -> Expectation
expect msg (Event event (QueryInternal.Single showTrace query)) =
    case toResult (Event event (QueryInternal.Single showTrace query)) of
        Err noEvent ->
            Expect.fail noEvent
                |> QueryInternal.failWithQuery showTrace "" query

        Ok foundMsg ->
            foundMsg
                |> Expect.equal msg
                |> QueryInternal.failWithQuery showTrace
                    ("Event.expectEvent: Expected the msg \u{001B}[32m"
                        ++ Internal.toString msg
                        ++ "\u{001B}[39m from the event \u{001B}[31m"
                        ++ Internal.toString event
                        ++ "\u{001B}[39m but could not find the event."
                    )
                    query


{-| Returns a Result with the Msg produced by the event simulated on a node.
Note that Event.expect gives nicer messages; this is generally more useful
when testing that an event handler is _not_ present.

    import Test.Html.Event as Event


    test "Input produces expected Msg" <|
        \() ->
            Html.input [ onInput Change ] [ ]
                |> Query.fromHtml
                |> Event.simulate (Event.input "cats")
                |> Event.toResult
                |> Expect.equal (Ok (Change "cats"))

-}
toResult : Event msg -> Result String msg
toResult (Event ( eventName, jsEvent ) (QueryInternal.Single showTrace query)) =
    let
        node =
            QueryInternal.traverse query
                |> Result.andThen (QueryInternal.verifySingle eventName)
                |> Result.mapError (QueryInternal.queryErrorToString query)
    in
    case node of
        Err msg ->
            Err msg

        Ok single ->
            findEvent eventName single
                |> Result.andThen
                    (\foundEvent ->
                        Decode.decodeValue foundEvent jsEvent
                            |> Result.mapError Decode.errorToString
                    )



-- EVENTS --


{-| A [`click`](https://developer.mozilla.org/en-US/docs/Web/Events/click) event.
-}
click : ( String, Value )
click =
    ( "click", emptyObject )


{-| A [`dblclick`](https://developer.mozilla.org/en-US/docs/Web/Events/dblclick) event.
-}
doubleClick : ( String, Value )
doubleClick =
    ( "dblclick", emptyObject )


{-| A [`mousedown`](https://developer.mozilla.org/en-US/docs/Web/Events/mousedown) event.
-}
mouseDown : ( String, Value )
mouseDown =
    ( "mousedown", emptyObject )


{-| A [`mouseup`](https://developer.mozilla.org/en-US/docs/Web/Events/mouseup) event.
-}
mouseUp : ( String, Value )
mouseUp =
    ( "mouseup", emptyObject )


{-| A [`mouseenter`](https://developer.mozilla.org/en-US/docs/Web/Events/mouseenter) event.
-}
mouseEnter : ( String, Value )
mouseEnter =
    ( "mouseenter", emptyObject )


{-| A [`mouseleave`](https://developer.mozilla.org/en-US/docs/Web/Events/mouseleave) event.
-}
mouseLeave : ( String, Value )
mouseLeave =
    ( "mouseleave", emptyObject )


{-| A [`mouseover`](https://developer.mozilla.org/en-US/docs/Web/Events/mouseover) event.
-}
mouseOver : ( String, Value )
mouseOver =
    ( "mouseover", emptyObject )


{-| A [`mouseout`](https://developer.mozilla.org/en-US/docs/Web/Events/mouseout) event.
-}
mouseOut : ( String, Value )
mouseOut =
    ( "mouseout", emptyObject )


{-| An [`input`](https://developer.mozilla.org/en-US/docs/Web/Events/input) event.
-}
input : String -> ( String, Value )
input value =
    ( "input"
    , Encode.object
        [ ( "target"
          , Encode.object [ ( "value", Encode.string value ) ]
          )
        ]
    )


{-| A [`change`](https://developer.mozilla.org/en-US/docs/Web/Events/change) event
where `event.target.checked` is set to the given `Bool` value.
-}
check : Bool -> ( String, Value )
check checked =
    ( "change"
    , Encode.object
        [ ( "target"
          , Encode.object [ ( "checked", Encode.bool checked ) ]
          )
        ]
    )


{-| A [`submit`](https://developer.mozilla.org/en-US/docs/Web/Events/submit) event.
-}
submit : ( String, Value )
submit =
    ( "submit", emptyObject )


{-| A [`blur`](https://developer.mozilla.org/en-US/docs/Web/Events/blur) event.
-}
blur : ( String, Value )
blur =
    ( "blur", emptyObject )


{-| A [`focus`](https://developer.mozilla.org/en-US/docs/Web/Events/focus) event.
-}
focus : ( String, Value )
focus =
    ( "focus", emptyObject )


{-| Simulate a custom event. The `String` is the event name, and the `Value` is the event object
the browser would send to the event listener callback.

    import Test.Html.Event as Event
    import Json.Encode as Encode exposing (Value)


    type Msg
        = Change String


    test "Input produces expected Msg" <|
        \() ->
            let
                simulatedEventObject : Value
                simulatedEventObject =
                    Encode.object
                        [ ( "target"
                          , Encode.object [ ( "value", Encode.string "cats" ) ]
                          )
                        ]
            in
                Html.input [ onInput Change ] [ ]
                    |> Query.fromHtml
                    |> Event.simulate (Event.custom "input" simulatedEventObject)
                    |> Event.expect (Change "cats")

-}
custom : String -> Value -> ( String, Value )
custom =
    Tuple.pair



-- INTERNAL --


emptyObject : Value
emptyObject =
    Encode.object []


findEvent : String -> ElmHtml msg -> Result String (Decoder msg)
findEvent eventName element =
    let
        elementOutput =
            QueryInternal.prettyPrint element

        handlerToDecoder : VirtualDom.Handler msg -> Decoder msg
        handlerToDecoder handler =
            -- NOTE: this is were we are dropping the information about stopPropagation and preventDefault
            -- In the future, we will want to expose this somehow (see https://github.com/eeue56/elm-html-test/issues/63)
            case handler of
                VirtualDom.Normal decoder ->
                    decoder

                VirtualDom.MayStopPropagation decoder ->
                    decoder |> Decode.map Tuple.first

                VirtualDom.MayPreventDefault decoder ->
                    decoder |> Decode.map Tuple.first

                VirtualDom.Custom decoder ->
                    decoder |> Decode.map .message

        eventDecoder node =
            node.facts.events
                |> Dict.get eventName
                |> Maybe.map handlerToDecoder
                |> Result.fromMaybe ("Event.expectEvent: I found a node, but it does not listen for \"" ++ eventName ++ "\" events like I expected it would.\n\n" ++ elementOutput)
    in
    case element of
        TextTag _ ->
            Err ("I found a text node instead of an element. Text nodes do not receive events, so it would be impossible to simulate \"" ++ eventName ++ "\" events on it. The text in the node was: \"" ++ elementOutput ++ "\"")

        NodeEntry node ->
            eventDecoder node

        CustomNode node ->
            eventDecoder node

        MarkdownNode node ->
            eventDecoder node

        NoOp ->
            Err ("I found an element I did not know how to deal with, so simulating \"" ++ eventName ++ "\" events on it would be impossible. This is a problem with elm-test! Sorry about that. If you have time, could you report this issue on https://github.com/elm-explorations/test/issues with a http://sscce.org to reproduce this error message?")
