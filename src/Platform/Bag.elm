module Platform.Bag exposing
  ( LeafType
  , EffectManagerName
  )

import Basics exposing (Never)
import String exposing (String)


type LeafType msg = LeafType Kernel


type EffectManagerName = EffectManagerName Kernel


type Kernel = Kernel Kernel
