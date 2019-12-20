module Platform.Bag exposing
  ( LeafType
  , EffectManagerName
  )


type LeafType msg = LeafType Kernel


type EffectManagerName = EffectManagerName Kernel


type Kernel = Kernel Kernel
