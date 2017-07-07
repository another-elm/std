module VirtualDom exposing
  ( Node
  , text, node, nodeNS
  , Attribute, style, property, attribute, attributeNS
  , on, onBubble, onCapture, Handler(..)
  , map, mapAttribute
  , lazy, lazy2, lazy3
  , keyedNode, keyedNodeNS
  , program, programWithFlags
  )

{-| API to the core diffing algorithm. Can serve as a foundation for libraries
that expose more helper functions for HTML or SVG.

# Create
@docs Node, text, node, nodeNS

# Attributes
@docs Attribute, style, property, attribute, attributeNS

# Events
@docs on, onBubble, onCapture, Handler

# Routing Messages
@docs map, mapAttribute

# Optimizations
@docs lazy, lazy2, lazy3, keyedNode, keyedNodeNS

# Programs
@docs program, programWithFlags

-}

import Elm.Kernel.VirtualDom
import Json.Decode as Json
import VirtualDom.Debug as Debug


{-| An immutable chunk of data representing a DOM node. This can be HTML or SVG.
-}
type Node msg = Node


{-| Create a DOM node with a tag name, a list of HTML properties that can
include styles and event listeners, a list of CSS properties like `color`, and
a list of child nodes.

    import Json.Encode as Json

    hello : Node msg
    hello =
      node "div" [] [ text "Hello!" ]

    greeting : Node msg
    greeting =
      node "div"
        [ property "id" (Json.string "greeting") ]
        [ text "Hello!" ]
-}
node : String -> List (Attribute msg) -> List (Node msg) -> Node msg
node =
  Elm.Kernel.VirtualDom.node


{-| Create a namespaced DOM node. For example, an SVG `<path>` node could be
defined like this:

    path : List (Attribute msg) -> List (Node msg) -> Node msg
    path attrubutes children =
      nodeNS "http://www.w3.org/2000/svg" "path" attributes children
-}
nodeNS : String -> String -> List (Attribute msg) -> List (Node msg) -> Node msg
nodeNS =
  Elm.Kernel.VirtualDom.nodeNS


{-| Just put plain text in the DOM. It will escape the string so that it appears
exactly as you specify.

    text "Hello World!"
-}
text : String -> Node msg
text =
  Elm.Kernel.VirtualDom.text


{-| This function is useful when nesting components with [the Elm
Architecture](https://github.com/evancz/elm-architecture-tutorial/). It lets
you transform the messages produced by a subtree.

Say you have a node named `button` that produces `()` values when it is
clicked. To get your model updating properly, you will probably want to tag
this `()` value like this:

    type Msg = Click | ...

    update msg model =
      case msg of
        Click ->
          ...

    view model =
      map (\_ -> Click) button

So now all the events produced by `button` will be transformed to be of type
`Msg` so they can be handled by your update function!
-}
map : (a -> msg) -> Node a -> Node msg
map =
  Elm.Kernel.VirtualDom.map



-- ATTRIBUTES


{-| When using HTML and JS, there are two ways to specify parts of a DOM node.

  1. Attributes &mdash; You can set things in HTML itself. So the `class`
     in `<div class="greeting"></div>` is called an *attribute*.

  2. Properties &mdash; You can also set things in JS. So the `className`
     in `div.className = 'greeting'` is called a *property*.

So the `class` attribute corresponds to the `className` property. At first
glance, perhaps this distinction is defensible, but it gets much crazier.
*There is not always a one-to-one mapping between attributes and properties!*
Yes, that is a true fact. Sometimes an attribute exists, but there is no
corresponding property. Sometimes changing an attribute does not change the
underlying property. For example, as of this writing, the `webkit-playsinline`
attribute can be used in HTML, but there is no corresponding property!
-}
type Attribute msg = Attribute


{-| Specify a style.

    greeting : Node msg
    greeting =
      node "div"
        [ style "backgroundColor" "red"
        , style "height" "90px"
        , style "width" "100%"
        ]
        [ text "Hello!"
        ]

-}
style : String -> String -> Attribute msg
style =
  Elm.Kernel.VirtualDom.style


{-| Create a property.

    import Json.Encode as Encode

    buttonLabel : Node msg
    buttonLabel =
      node "label" [ property "htmlFor" (Encode.string "button") ] [ text "Label" ]

Notice that you must give the *property* name, so we use `htmlFor` as it
would be in JavaScript, not `for` as it would appear in HTML.
-}
property : String -> Json.Value -> Attribute msg
property =
  Elm.Kernel.VirtualDom.property


{-| Create an attribute. This uses JavaScript’s `setAttribute` function
behind the scenes.

    buttonLabel : Node msg
    buttonLabel =
      node "label" [ attribute "for" "button" ] [ text "Label" ]

Notice that you must give the *attribute* name, so we use `for` as it would
be in HTML, not `htmlFor` as it would appear in JS.
-}
attribute : String -> String -> Attribute msg
attribute =
  Elm.Kernel.VirtualDom.attribute


{-| Would you believe that there is another way to do this?! This uses
JavaScript's `setAttributeNS` function behind the scenes. It is doing pretty
much the same thing as `attribute` but you are able to have namespaced
attributes. As an example, the `elm-lang/svg` package defines an attribute
like this:

    xlinkHref : String -> Attribute msg
    xlinkHref value =
      attributeNS "http://www.w3.org/1999/xlink" "xlink:href" value
-}
attributeNS : String -> String -> String -> Attribute msg
attributeNS =
  Elm.Kernel.VirtualDom.attributeNS


{-| Transform the messages produced by a `Attribute`.
-}
mapAttribute : (a -> b) -> Attribute a -> Attribute b
mapAttribute =
  Elm.Kernel.VirtualDom.mapAttribute



-- EVENTS


{-| Create a custom event listener.

    import Json.Decode as Decode

    onClick : msg -> Attribute msg
    onClick msg =
      on "click" (Decode.succeed msg)

You first specify the name of the event in the same format as with JavaScript’s
`addEventListener`. Next you give a JSON decoder, which lets you pull
information out of the event object. If the decoder succeeds, it will produce
a message and route it to your `update` function.
-}
on : String -> Json.Decoder msg -> Attribute msg
on eventName decoder =
  onBubble eventName (Simple decoder)


{-| For very custom event handlers. These handlers will activate during the
“bubble” phase, when events travel from leaf to root, as described
[here](https://www.quirksmode.org/js/events_order.html).

**This is the default**, so you can define `on` like this:

    import Json.Decode exposing (Decoder)

    on : String -> Decoder msg -> Attribute msg
    on eventName decoder =
      onBubble eventName (Simple decoder)
-}
onBubble : String -> Handler msg -> Attribute msg
onBubble =
  Elm.Kernel.VirtualDom.on False


{-| For very custom event handlers. These handlers will activate during the
“capture” phase, when events travel from root to leaf, as described
[here](https://www.quirksmode.org/js/events_order.html).

**This is very rarely what you want.**
-}
onCapture : String -> Handler msg -> Attribute msg
onCapture =
  Elm.Kernel.VirtualDom.on True


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



-- OPTIMIZATION


{-| A performance optimization that delays the building of virtual DOM nodes.

Calling `(view model)` will definitely build some virtual DOM, perhaps a lot of
it. Calling `(lazy view model)` delays the call until later. During diffing, we
can check to see if `model` is referentially equal to the previous value used,
and if so, we just stop. No need to build up the tree structure and diff it,
we know if the input to `view` is the same, the output must be the same!
-}
lazy : (a -> Node msg) -> a -> Node msg
lazy =
  Elm.Kernel.VirtualDom.lazy


{-| Same as `lazy` but checks on two arguments.
-}
lazy2 : (a -> b -> Node msg) -> a -> b -> Node msg
lazy2 =
  Elm.Kernel.VirtualDom.lazy2


{-| Same as `lazy` but checks on three arguments.
-}
lazy3 : (a -> b -> c -> Node msg) -> a -> b -> c -> Node msg
lazy3 =
  Elm.Kernel.VirtualDom.lazy3


{-| Works just like `node`, but you add a unique identifier to each child
node. You want this when you have a list of nodes that is changing: adding
nodes, removing nodes, etc. In these cases, the unique identifiers help make
the DOM modifications more efficient.
-}
keyedNode : String -> List (Attribute msg) -> List ( String, Node msg ) -> Node msg
keyedNode =
  Elm.Kernel.VirtualDom.keyedNode


{-| Create a keyed and namespaced DOM node. For example, an SVG `<g>` node
could be defined like this:

    g : List (Attribute msg) -> List ( String, Node msg ) -> Node msg
    g =
      keyedNodeNS "http://www.w3.org/2000/svg" "g"
-}
keyedNodeNS : String -> String -> List (Attribute msg) -> List ( String, Node msg ) -> Node msg
keyedNodeNS =
  Elm.Kernel.VirtualDom.keyedNodeNS



-- PROGRAMS


{-| Check out the docs for [`Html.App.program`][prog].
It works exactly the same way.

[prog]: http://package.elm-lang.org/packages/elm-lang/html/latest/Html-App#program
-}
program
  : { init : (model, Cmd msg)
    , update : msg -> model -> (model, Cmd msg)
    , subscriptions : model -> Sub msg
    , view : model -> Node msg
    }
  -> Program Never model msg
program impl =
  Elm.Kernel.VirtualDom.program Debug.wrap impl


{-| Check out the docs for [`Html.App.programWithFlags`][prog].
It works exactly the same way.

[prog]: http://package.elm-lang.org/packages/elm-lang/html/latest/Html-App#programWithFlags
-}
programWithFlags
  : { init : flags -> (model, Cmd msg)
    , update : msg -> model -> (model, Cmd msg)
    , subscriptions : model -> Sub msg
    , view : model -> Node msg
    }
  -> Program flags model msg
programWithFlags impl =
  Elm.Kernel.VirtualDom.programWithFlags Debug.wrapWithFlags impl

