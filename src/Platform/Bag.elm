module Platform.Bag exposing
  ( Bag
  , batch
  , map
  )

{-|

> **Note:** Elm has **managed effects**, meaning that things like HTTP
> requests or writing to disk are all treated as *data* in Elm. When this
> data is given to the Elm runtime system, it can do some “query optimization”
> before actually performing the effect. Perhaps unexpectedly, this managed
> effects idea is the heart of why Elm is so nice for testing, reuse,
> reproducibility, etc.
>
> Elm has two kinds of managed effects: commands and subscriptions.

# Commands
@docs Bag, none, batch

# Fancy Stuff
@docs map

-}

import String exposing (String)
import Basics exposing (Never)

{-| Generic bag type, for Cmds or Subs.

Any changes to this type definition need to be reflected in Elm/Kernel/Platform.js
-}
type Bag msg
    = Leaf -- let kernel code handle this one
    | Batch (List (Bag msg))
    | Map (BagHiddenValue -> msg) (Bag BagHiddenValue)


batch : List (Bag msg) -> Bag msg
batch bag =
  Batch bag


map : (a -> msg) -> Bag a -> Bag msg
map fn bag =
  Map (Elm.Kernel.Basics.fudgeType fn) (Elm.Kernel.Basics.fudgeType bag)

type BagHiddenValue = BagHiddenValue Never
