module Platform.Raw.Effect exposing
    ( HiddenConvertedSubType
    , RawSub
    , RuntimeId
    , SubId
    )


type alias RawSub msg =
    List ( SubId, HiddenConvertedSubType -> msg )


type SubId
    = SubId SubId


type HiddenConvertedSubType
    = HiddenConvertedSubType HiddenConvertedSubType


type RuntimeId
    = RuntimeId RuntimeId
