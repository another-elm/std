module Platform.Raw.Sub exposing
    ( HiddenConvertedSubType
    , Id
    , RawSub
    )


type alias RawSub msg =
    List ( Id, HiddenConvertedSubType -> msg )


type Id
    = Id Id


type HiddenConvertedSubType
    = HiddenConvertedSubType HiddenConvertedSubType
