module Platform.Bag exposing
  ( Bag(..)
  , batch
  , map
  )

import Basics exposing (Never)

{-| Generic bag type, for Cmds or Subs.

Any changes to this type definition need to be reflected in Elm/Kernel/Platform.js
-}
type Bag msg
    = Leaf -- let kernel code handle this one
    | Batch (List (Bag msg))
    | Map (BagHiddenValue -> msg) (Bag BagHiddenValue)
    | Self msg


batch : List (Bag msg) -> Bag msg
batch bag =
  Batch bag


map : (a -> msg) -> Bag a -> Bag msg
map fn bag =
  Map (Elm.Kernel.Basics.fudgeType fn) (Elm.Kernel.Basics.fudgeType bag)

type BagHiddenValue = BagHiddenValue Never
