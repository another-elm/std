module Platform.Bag exposing
    ( EffectBag
    , EffectManagerName
    , LeafType
    )


type alias EffectBag msg =
    List
        { home : EffectManagerName
        , value : LeafType msg
        }


type LeafType msg
    = LeafType Kernel


type EffectManagerName
    = EffectManagerName Kernel


type Kernel
    = Kernel Kernel
