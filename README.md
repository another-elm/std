# SVG in Elm

Scalable vector graphics (SVG) is a way to display lines, rectangles, circles, arcs, etc.

The API is a bit wonky, but (1) it is manageable if you look through MDN docs like [these](https://developer.mozilla.org/en-US/docs/Web/SVG/Element/rect) and (2) you can attach event listeners to any shapes and lines you create!


## Example

```elm
import Svg exposing (..)
import Svg.Attributes exposing (..)

main =
  svg
    [ width "120"
    , height "120"
    , viewBox "0 0 120 120"
    ]
    [ rect
        [ x "10"
        , y "10"
        , width "100"
        , height "100"
        , rx "15"
        , ry "15"
        ]
        []
    , circle
        [ cx "50"
        , cy "50"
        , r "50"
        ]
        []
    ]
```

I highly recommend consulting the MDN docs on SVG to learn how to draw various shapes!


## Make visualizations!

SVG is great for data visualizations, and I really want people in the Elm community to explore more in that direction! My instinct is that functions like `view : data -> Svg msg` will be way easier to work with than what is available in other languages. Just give the data! No need to have data and interaction deeply interwoven in complex ways.

### Make visualization packages?

I think [`terezka/line-charts`](https://terezka.github.io/line-charts/) is a really great effort in this direction. Notice that [the docs](https://package.elm-lang.org/packages/terezka/line-charts/1.0.0/LineChart) present a really smooth learning path. Getting something on screen is really simple, and then it builds on that basic understanding to give you more capabilities. There are tons of examples as well. I really love seeing work like this!

So if you are interested in doing something like this, I recommend:

- Reading [The Visual Display of Quantitative Information](https://www.edwardtufte.com/tufte/books_vdqi) by Edward Tufte.
- Learning about [designing for color blindness](https://www.alanzucconi.com/2015/12/16/color-blindness/)
- Learning about different color spaces, like [CIELUV](https://en.wikipedia.org/wiki/CIELUV) for changing colors without changing the perceived brightness, [cubehelix](https://www.mrao.cam.ac.uk/~dag/CUBEHELIX/) for heatmaps with nice brightness properties, and how to do [color conversions](https://www.cs.rit.edu/~ncs/color/t_convert.html) in general

In other words, try to learn as much as possible first! Anyone can show dots on a grid, but a great package will build expertise into the API itself, quietly leading people towards better design and accessibility. Ideally it will help people learn the important principles as well, because it is not just about getting data on screen, it is about helping people understand complex information!


## Future Plans

This package should only change to account for new SVG tags and attributes.

Just like [`elm/html`](https://package.elm-lang.org/packages/elm/html/latest), this package is designed to be predictable. Every node takes two arguments (a list of attributes and a list of children) even though in many cases it is possible to do something nicer. So if you want nice helpers for simple shapes (for example) I recommend creating a separate package that builds upon this one.
