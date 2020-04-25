module Platform.Raw.Sub exposing
    ( RawSub
    , Id
    , HiddenConvertedSubType
    )


type alias RawSub msg =
    List ( Id, HiddenConvertedSubType -> msg )

type Id
    = Id Id


type HiddenConvertedSubType
    = HiddenConvertedSubType HiddenConvertedSubType
