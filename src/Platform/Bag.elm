module Platform.Bag exposing
  ( LeafType
  , EffectManagerName
  , EffectBag
  )


type alias EffectBag msg =
  List
    { home : EffectManagerName
    , value : (LeafType msg)
    }


type LeafType msg = LeafType Kernel


type EffectManagerName = EffectManagerName Kernel


type Kernel = Kernel Kernel
