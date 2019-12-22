module Platform.Sub exposing
    ( Sub, none, batch
    , map
    )

{-|

> **Note:** Elm has **managed effects**, meaning that things like HTTP
> requests or writing to disk are all treated as _data_ in Elm. When this
> data is given to the Elm runtime system, it can do some “query optimization”
> before actually performing the effect. Perhaps unexpectedly, this managed
> effects idea is the heart of why Elm is so nice for testing, reuse,
> reproducibility, etc.
>
> Elm has two kinds of managed effects: commands and subscriptions.


# Subscriptions

@docs Sub, none, batch


# Fancy Stuff

@docs map

-}

import Basics exposing (..)
import Elm.Kernel.Basics
import List
import Platform.Bag as Bag



-- SUBSCRIPTIONS


{-| A subscription is a way of telling Elm, “Hey, let me know if anything
interesting happens over there!” So if you want to listen for messages on a web
socket, you would tell Elm to create a subscription. If you want to get clock
ticks, you would tell Elm to subscribe to that. The cool thing here is that
this means _Elm_ manages all the details of subscriptions instead of _you_.
So if a web socket goes down, _you_ do not need to manually reconnect with an
exponential backoff strategy, _Elm_ does this all for you behind the scenes!

Every `Sub` specifies (1) which effects you need access to and (2) the type of
messages that will come back into your application.

**Note:** Do not worry if this seems confusing at first! As with every Elm user
ever, subscriptions will make more sense as you work through [the Elm Architecture
Tutorial](https://guide.elm-lang.org/architecture/) and see how they fit
into a real application!

-}
type Sub msg
    = Data (Bag.EffectBag msg)


{-| Tell the runtime that there are no subscriptions.
-}
none : Sub msg
none =
    batch []


{-| When you need to subscribe to multiple things, you can create a `batch` of
subscriptions.

**Note:** `Sub.none` and `Sub.batch [ Sub.none, Sub.none ]` and
`Sub.batch []` all do the same thing.

-}
batch : List (Sub msg) -> Sub msg
batch =
    List.map (\(Data sub) -> sub)
        >> List.concat
        >> Data



-- FANCY STUFF


{-| Transform the messages produced by a subscription.
Very similar to [`Html.map`](/packages/elm/html/latest/Html#map).

This is very rarely useful in well-structured Elm code, so definitely read the
section on [structure] in the guide before reaching for this!

[structure]: https://guide.elm-lang.org/webapps/structure.html

-}
map : (a -> msg) -> Sub a -> Sub msg
map fn (Data data) =
    data
        |> List.map
            (\{ home, value } ->
                { home = home
                , value = getSubMapper home fn value
                }
            )
        |> Data



-- Kernel function redefinitons --


getSubMapper : Bag.EffectManagerName -> (a -> msg) -> Bag.LeafType a -> Bag.LeafType msg
getSubMapper home =
    Elm.Kernel.Platform.getSubMapper home
