# HTML for Elm

Quickly render HTML in Elm.


## Examples

You can see a bunch of examples [here](http://elm-lang.org/examples).

The simplest one one is a counter that you can increment and decrement ([code](http://elm-lang.org/examples/buttons) / [explanation](https://guide.elm-lang.org/architecture/user_input/buttons.html)). The HTML part of that program looks like this:

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

-- If you call `view 42` you get something like this:
--
-- <div>
--   <button>-</button>
--   <div>42</div>
--   <button>+</button>
-- </div>
--
```

Again, you can see the full code [here](http://elm-lang.org/examples/buttons) and read how it works [here](https://guide.elm-lang.org/architecture/user_input/buttons.html).


## Learn More

**Definitely read through [guide.elm-lang.org](http://guide.elm-lang.org/) to understand how this all works!** The section on [The Elm Architecture](http://guide.elm-lang.org/architecture/index.html) is particularly helpful.


## Implementation

This library is backed by [elm-lang/virtual-dom](http://package.elm-lang.org/packages/elm-lang/virtual-dom/latest/) which handles the dirty details of rendering DOM nodes quickly. You can read some blog posts about it here:

  - [Blazing Fast HTML, Round Two](http://elm-lang.org/blog/blazing-fast-html-round-two)
  - [Blazing Fast HTML](http://elm-lang.org/blog/blazing-fast-html)
