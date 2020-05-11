# Elm in the Browser!

This package allows you to create Elm programs that run in browsers.


## Learning Path

**I highly recommend working through [guide.elm-lang.org][guide] to learn how to use Elm.** It is built around a learning path that introduces concepts gradually.

[guide]: https://guide.elm-lang.org/

You can see the outline of that learning path in the `Browser` module. It lets you create Elm programs with the following functions:

  1. [`sandbox`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#sandbox) &mdash; react to user input, like buttons and checkboxes
  2. [`element`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#element) &mdash; talk to the outside world, like HTTP and JS interop
  3. [`document`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#document) &mdash; control the `<title>` and `<body>`
  4. [`application`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#application) &mdash; create single-page apps

This order works well because important concepts and techniques are introduced at each stage. If you jump ahead, it is like building a house by starting with the roof! So again, **work through [guide.elm-lang.org][guide] to see examples and really *understand* how Elm works!**

This order also works well because it mirrors how most people introduce Elm at work. Start small. Try using Elm in a single element in an existing JavaScript project. If that goes well, try doing a bit more. Etc.

## Virtual DOM for Elm

A virtual DOM implementation that backs Elm's core libraries for [HTML](https://package.elm-lang.org/packages/elm/html/latest/) and [SVG](https://package.elm-lang.org/packages/elm/svg/latest/). You should almost certainly use those higher-level libraries directly.

It is pretty fast! You can read about that [here](https://elm-lang.org/blog/blazing-fast-html-round-two).

## HTML

Quickly render HTML in Elm. The HTML part of an Elm program looks something like this:

```elm
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)

type Msg = Increment | Decrement

view : Int -> Html Msg
view count =
  div []
    [ button [ onClick Decrement ] [ text "-" ]
    , div [] [ text (String.fromInt count) ]
    , button [ onClick Increment ] [ text "+" ]
    ]
```

If you call `view 42` you get something like this:

```html
<div>
  <button>-</button>
  <div>42</div>
  <button>+</button>
</div>
```

This snippet comes from a complete example. You can play with it online [here](https://elm-lang.org/examples/buttons) and read how it works [here](https://guide.elm-lang.org/architecture/user_input/buttons.html).

You can play with a bunch of other examples [here](https://elm-lang.org/examples).
