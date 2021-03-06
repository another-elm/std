-- effect module Browser.Events where { subscription = MySub } exposing
module Browser.Events exposing
  ( onAnimationFrame, onAnimationFrameDelta
  , onKeyPress, onKeyDown, onKeyUp
  , onClick, onMouseMove, onMouseDown, onMouseUp
  , onResize, onVisibilityChange, Visibility(..)
  )

{-| In JavaScript, information about the root of an HTML document is held in
the `document` and `window` objects. This module lets you create event
listeners on those objects for the following topics: [animation](#animation),
[keyboard](#keyboard), [mouse](#mouse), and [window](#window).

If there is something else you need, use [ports] to do it in JavaScript!

[ports]: https://guide.elm-lang.org/interop/ports.html


# Animation

@docs onAnimationFrame, onAnimationFrameDelta


# Keyboard

@docs onKeyPress, onKeyDown, onKeyUp


# Mouse

@docs onClick, onMouseMove, onMouseDown, onMouseUp


# Window

@docs onResize, onVisibilityChange, Visibility

-}

import Elm.Kernel.Browser
import Json.Decode as Decode
import Time
import Platform.Unstable.SubManager as SubManager
import Platform.Unstable.Impure as Impure
import Platform.Unstable.Effect as Effect



-- ANIMATION


{-| An animation frame triggers about 60 times per second. Get the POSIX time
on each frame. (See [`elm/time`](/packages/elm/time/latest) for more info on
POSIX times.)

**Note:** Browsers have their own render loop, repainting things as fast as
possible. If you want smooth animations in your application, it is helpful to
sync up with the browsers natural refresh rate. This hooks into JavaScript's
`requestAnimationFrame` function.

-}
onAnimationFrame : (Time.Posix -> msg) -> Sub msg
onAnimationFrame tagger =
  animationFrameSubscription (\{now} -> now |> Time.millisToPosix |> tagger |> Just )


{-| Just like `onAnimationFrame`, except message is the time in milliseconds
since the previous frame. So you should get a sequence of values all around
`1000 / 60` which is nice for stepping animations by a time delta.
-}
onAnimationFrameDelta : (Float -> msg) -> Sub msg
onAnimationFrameDelta tagger =
  animationFrameSubscription (\{delta} ->  delta |> tagger |> Just )



-- KEYBOARD


{-| Subscribe to key presses that normally produce characters. So you should
not rely on this for arrow keys.

**Note:** Check out [this advice][note] to learn more about decoding key codes.
It is more complicated than it should be.

[note]: https://github.com/elm/browser/blob/1.0.2/notes/keyboard.md

-}
onKeyPress : Decode.Decoder msg -> Sub msg
onKeyPress =
  on Document "keypress"


{-| Subscribe to get codes whenever a key goes down. This can be useful for
creating games. Maybe you want to know if people are pressing `w`, `a`, `s`,
or `d` at any given time.

**Note:** Check out [this advice][note] to learn more about decoding key codes.
It is more complicated than it should be.

[note]: https://github.com/elm/browser/blob/1.0.2/notes/keyboard.md

-}
onKeyDown : Decode.Decoder msg -> Sub msg
onKeyDown =
  on Document "keydown"


{-| Subscribe to get codes whenever a key goes up. Often used in combination
with [`onVisibilityChange`](#onVisibilityChange) to be sure keys do not appear
to down and never come back up.
-}
onKeyUp : Decode.Decoder msg -> Sub msg
onKeyUp =
  on Document "keyup"



-- MOUSE


{-| Subscribe to mouse clicks anywhere on screen. Maybe you need to create a
custom drop down. You could listen for clicks when it is open, letting you know
if someone clicked out of it:

    import Browser.Events as Events
    import Json.Decode as D

    type Msg
       = ClickOut

    subscriptions : Model -> Sub Msg
    subscriptions model =
      case model.dropDown of
        Closed _ ->
          Sub.none

        Open _ ->
          Events.onClick (D.succeed ClickOut)

-}
onClick : Decode.Decoder msg -> Sub msg
onClick =
  on Document "click"


{-| Subscribe to mouse moves anywhere on screen.

You could use this to implement resizable panels like in Elm's online code
editor. Check out the example imprementation [here][drag].

[drag]: https://github.com/elm/browser/blob/1.0.2/examples/src/Drag.elm

**Note:** Unsubscribe if you do not need these events! Running code on every
single mouse movement can be very costly, and it is recommended to only
subscribe when absolutely necessary.

-}
onMouseMove : Decode.Decoder msg -> Sub msg
onMouseMove =
  on Document "mousemove"


{-| Subscribe to get mouse information whenever the mouse button goes down.
-}
onMouseDown : Decode.Decoder msg -> Sub msg
onMouseDown =
  on Document "mousedown"


{-| Subscribe to get mouse information whenever the mouse button goes up.
Often used in combination with [`onVisibilityChange`](#onVisibilityChange)
to be sure keys do not appear to down and never come back up.
-}
onMouseUp : Decode.Decoder msg -> Sub msg
onMouseUp =
  on Document "mouseup"



-- WINDOW


{-| Subscribe to any changes in window size.

For example, you could track the current width by saying:

    import Browser.Events as E

    type Msg
      = GotNewWidth Int

    subscriptions : model -> Cmd Msg
    subscriptions _ =
      E.onResize (\w h -> GotNewWidth w)

**Note:** This is equivalent to getting events from [`window.onresize`][resize].

[resize]: https://developer.mozilla.org/en-US/docs/Web/API/GlobalEventHandlers/onresize

-}
onResize : (Int -> Int -> msg) -> Sub msg
onResize func =
  on Window "resize" <|
    Decode.field "target" <|
      Decode.map2 func
        (Decode.field "innerWidth" Decode.int)
        (Decode.field "innerHeight" Decode.int)


{-| Subscribe to any visibility changes, like if the user switches to a
different tab or window. When the user looks away, you may want to:

- Pause a timer.
- Pause an animation.
- Pause video or audio.
- Pause an image carousel.
- Stop polling a server for new information.
- Stop waiting for an [`onKeyUp`](#onKeyUp) event.

-}
onVisibilityChange : (Visibility -> msg) -> Sub msg
onVisibilityChange func =
  let
    info = visibilityInfo ()
  in
  on Document info.change <|
    Decode.map (withHidden func) <|
      Decode.field "target" <|
        Decode.field info.hidden Decode.bool


withHidden : (Visibility -> msg) -> Bool -> msg
withHidden func isHidden =
  func (if isHidden then Hidden else Visible)


{-| Value describing whether the page is hidden or visible.
-}
type Visibility
  = Visible
  | Hidden



-- SUBSCRIPTIONS


type Node
  = Document
  | Window


on : Node -> String -> Decode.Decoder msg -> Sub msg
on node name decoder =
  subscription (node, name) (decodeEvent decoder)



subscription : (Node, String) -> (RawEvent -> Maybe msg) -> Sub msg
subscription =
  Tuple.first
    (SubManager.subscriptionManager
      (Effect.EventListener
        { discontinued = rawOff
        , new = \(node, name) ->
          let
            actualNode =
              case node of
                Document -> doc
                Window -> window
          in
          rawOn actualNode name
        }
      )
      (\(node, name) ->
        (case node of
          Document -> "Document"
          Window -> "Window"
        )
          ++ "::" ++ name
      )
    )


type alias AnimationFramePayload =
  { now: Int
  , delta: Float
  }


animationFrameSubscription : (AnimationFramePayload -> Maybe msg) -> Sub msg
animationFrameSubscription =
  Tuple.first
    (SubManager.subscriptionManager
      (Effect.EventListener
        { new = \() -> animationFrameOn
        , discontinued = animationFrameOff
        }
      )
      (\() -> "raf")
    )
    ()


type HtmlNode
  = Stub_HtmlNode


type RawEvent
  = RawEvent RawEvent


type alias  VisibilityInfo =
  { hidden : String
  , change : String
  }


{-| TODO(harry): make this an impure function.
-}
visibilityInfo : () -> VisibilityInfo
visibilityInfo =
  Elm.Kernel.Browser.visibilityInfo


decodeEvent : Decode.Decoder msg -> RawEvent -> Maybe msg
decodeEvent =
  Elm.Kernel.Browser.decodeEvent


rawOn : HtmlNode -> String -> Impure.Function (Impure.Function RawEvent ()) Effect.EffectId
rawOn =
  Elm.Kernel.Browser.on


rawOff : Impure.Function Effect.EffectId ()
rawOff =
  Elm.Kernel.Browser.off


doc : HtmlNode
doc =
  Elm.Kernel.Browser.doc


window : HtmlNode
window =
  Elm.Kernel.Browser.window

animationFrameOn : Impure.Function (Impure.Function AnimationFramePayload ()) Effect.EffectId
animationFrameOn =
  Elm.Kernel.Browser.animationFrameOn


animationFrameOff : Impure.Function Effect.EffectId ()
animationFrameOff =
  Elm.Kernel.Browser.animationFrameOff
