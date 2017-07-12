module Html.Events exposing
  ( onClick, onDoubleClick
  , onMouseDown, onMouseUp
  , onMouseEnter, onMouseLeave
  , onMouseOver, onMouseOut
  , onInput, onCheck, onSubmit
  , onBlur, onFocus
  , on, onBubble, onCapture, Handler(..)
  , targetValue, targetChecked, keyCode
  )

{-|
It is often helpful to create an [Union Type][] so you can have many different kinds
of events as seen in the [TodoMVC][] example.

[Union Type]: http://elm-lang.org/learn/Union-Types.elm
[TodoMVC]: https://github.com/evancz/elm-todomvc/blob/master/Todo.elm

# Mouse Helpers
@docs onClick, onDoubleClick,
      onMouseDown, onMouseUp,
      onMouseEnter, onMouseLeave,
      onMouseOver, onMouseOut

# Form Helpers
@docs onInput, onCheck, onSubmit

# Focus Helpers
@docs onBlur, onFocus

# Custom Event Handlers
@docs on, onBubble, onCapture, Handler

# Custom Decoders
@docs targetValue, targetChecked, keyCode
-}

import Html exposing (Attribute)
import Json.Decode as Json
import VirtualDom



-- MOUSE EVENTS


{-|-}
onClick : msg -> Attribute msg
onClick msg =
  on "click" (Json.succeed msg)


{-|-}
onDoubleClick : msg -> Attribute msg
onDoubleClick msg =
  on "dblclick" (Json.succeed msg)


{-|-}
onMouseDown : msg -> Attribute msg
onMouseDown msg =
  on "mousedown" (Json.succeed msg)


{-|-}
onMouseUp : msg -> Attribute msg
onMouseUp msg =
  on "mouseup" (Json.succeed msg)


{-|-}
onMouseEnter : msg -> Attribute msg
onMouseEnter msg =
  on "mouseenter" (Json.succeed msg)


{-|-}
onMouseLeave : msg -> Attribute msg
onMouseLeave msg =
  on "mouseleave" (Json.succeed msg)


{-|-}
onMouseOver : msg -> Attribute msg
onMouseOver msg =
  on "mouseover" (Json.succeed msg)


{-|-}
onMouseOut : msg -> Attribute msg
onMouseOut msg =
  on "mouseout" (Json.succeed msg)



-- FORM EVENTS


{-| Detect [input](https://developer.mozilla.org/en-US/docs/Web/Events/input)
events for things like text fields or text areas.

It grabs the **string** value at `event.target.value`, so it will not work if
you need some other type of information. For example, if you want to track
inputs on a range slider, make a custom handler with [`on`](#on).

For more details on how `onInput` works, check out [targetValue](#targetValue).
-}
onInput : (String -> msg) -> Attribute msg
onInput tagger =
  on "input" (Json.map tagger targetValue)


{-| Detect [change](https://developer.mozilla.org/en-US/docs/Web/Events/change)
events on checkboxes. It will grab the boolean value from `event.target.checked`
on any input event.

Check out [targetChecked](#targetChecked) for more details on how this works.
-}
onCheck : (Bool -> msg) -> Attribute msg
onCheck tagger =
  on "change" (Json.map tagger targetChecked)


{-| Detect a [submit](https://developer.mozilla.org/en-US/docs/Web/Events/submit)
event with [`preventDefault`](https://developer.mozilla.org/en-US/docs/Web/API/Event/preventDefault)
in order to prevent the form from changing the page’s location. If you need
different behavior, use `onBubble` to modify these defaults.
-}
onSubmit : msg -> Attribute msg
onSubmit msg =
  onBubble "submit" <|
    MayPreventDefault (Json.map preventDefault (Json.succeed msg))


preventDefault : msg -> ( msg, Bool )
preventDefault msg =
  ( msg, True )



-- FOCUS EVENTS


{-|-}
onBlur : msg -> Attribute msg
onBlur msg =
  on "blur" (Json.succeed msg)


{-|-}
onFocus : msg -> Attribute msg
onFocus msg =
  on "focus" (Json.succeed msg)



-- CUSTOM EVENTS


{-| Create a custom event listener. Normally this will not be necessary, but
you have the power! Here is how `onClick` is defined for example:

    import Json.Decode as Decode

    onClick : msg -> Attribute msg
    onClick message =
      on "click" (Decode.succeed message)

The first argument is the event name in the same format as with JavaScript's
[`addEventListener`][aEL] function.

The second argument is a JSON decoder. Read more about these [here][decoder].
When an event occurs, the decoder tries to turn the event object into an Elm
value. If successful, the value is routed to your `update` function. In the
case of `onClick` we always just succeed with the given `message`.

If this is confusing, work through the [Elm Architecture Tutorial][tutorial].
It really does help!

[aEL]: https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener
[decoder]: http://package.elm-lang.org/packages/elm-lang/core/latest/Json-Decode
[tutorial]: https://github.com/evancz/elm-architecture-tutorial/
-}
on : String -> Json.Decoder msg -> Attribute msg
on =
  VirtualDom.on


{-| **This is the default event primitive.**

It lets you create very custom event handlers. These handlers activate during
the “bubble” phase, as described [here][]. This is the default behavior of
event handlers in JavaScript, so using `addEventListener` normally will work
the same way.

[here]: https://www.quirksmode.org/js/events_order.html

We actually define `on` using `onBubble` like this:

    import Json.Decode exposing (Decoder)

    on : String -> Decoder msg -> Attribute msg
    on eventName decoder =
      onBubble eventName (Simple decoder)
-}
onBubble : String -> Handler msg -> Attribute msg
onBubble name handler =
  VirtualDom.onBubble name (convertHandler handler)


{-| **This is the weird event primitive.**

It lets you create very custom event handlers. These handlers activate during
the “capture” phase, as described [here][]. This is only useful in very odd
circumstances and is generally advised against. This is included mainly to
have parity with the underlying browser API just in case.

[here]: https://www.quirksmode.org/js/events_order.html
-}
onCapture : String -> Handler msg -> Attribute msg
onCapture name handler =
  VirtualDom.onCapture name (convertHandler handler)


convertHandler : Handler msg -> VirtualDom.Handler msg
convertHandler handler =
  case handler of
    Simple decoder ->
      VirtualDom.Simple decoder

    MayStopPropagation decoder ->
      VirtualDom.MayStopPropagation decoder

    MayPreventDefault decoder ->
      VirtualDom.MayPreventDefault decoder

    Fancy decoder ->
      VirtualDom.Fancy decoder



{-| When using `onBubble` or `onCapture` you can customize the event behavior
a bit. There are two ways to do this:

  - `stopPropagation = True` means the event stops traveling through the DOM.
  So if propagation of a click is stopped, it will not trigger any other event
  listeners.

  - `preventDefault = True` means any built-in browser behavior related to the
  event is prevented. This can be handy with key presses or touch gestures.

**Note:** A [passive][] event listener will be created if you use `Simple`
or `MayStopPropagation`. In both cases `preventDefault` cannot be used, so
we can enable optimizations for touch, scroll, and wheel events in some
browsers.

[passive]: https://github.com/WICG/EventListenerOptions/blob/gh-pages/explainer.md
-}
type Handler msg
  = Simple (Json.Decoder msg)
  | MayStopPropagation (Json.Decoder (msg, Bool))
  | MayPreventDefault (Json.Decoder (msg, Bool))
  | Fancy (Json.Decoder { message : msg, stopPropagation : Bool, preventDefault : Bool })




-- COMMON DECODERS


{-| A `Json.Decoder` for grabbing `event.target.value`. We use this to define
`onInput` as follows:

    import Json.Decode as Json

    onInput : (String -> msg) -> Attribute msg
    onInput tagger =
      on "input" (Json.map tagger targetValue)

You probably will never need this, but hopefully it gives some insights into
how to make custom event handlers.
-}
targetValue : Json.Decoder String
targetValue =
  Json.at ["target", "value"] Json.string


{-| A `Json.Decoder` for grabbing `event.target.checked`. We use this to define
`onCheck` as follows:

    import Json.Decode as Json

    onCheck : (Bool -> msg) -> Attribute msg
    onCheck tagger =
      on "input" (Json.map tagger targetChecked)
-}
targetChecked : Json.Decoder Bool
targetChecked =
  Json.at ["target", "checked"] Json.bool


{-| A `Json.Decoder` for grabbing `event.keyCode`. This helps you define
keyboard listeners like this:

    import Json.Decode as Json

    onKeyUp : (Int -> msg) -> Attribute msg
    onKeyUp tagger =
      on "keyup" (Json.map tagger keyCode)

**Note:** It looks like the spec is moving away from `event.keyCode` and
towards `event.key`. Once this is supported in more browsers, we may add
helpers here for `onKeyUp`, `onKeyDown`, `onKeyPress`, etc.
-}
keyCode : Json.Decoder Int
keyCode =
  Json.field "keyCode" Json.int
