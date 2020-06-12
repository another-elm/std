module Platform.Raw.Effect exposing
    ( HiddenConvertedSubType
    , RawSub
    , Runtime
    , RuntimeId
    , SubId
    , getId
    )

import Elm.Kernel.Basics


type alias RawSub msg =
    List ( SubId, HiddenConvertedSubType -> msg )


type SubId
    = SubId SubId


type HiddenConvertedSubType
    = HiddenConvertedSubType HiddenConvertedSubType


type RuntimeId
    = RuntimeId RuntimeId


type Runtime msg
    = Runtime (Runtime msg)


getId : Runtime msg -> RuntimeId
getId =
    Elm.Kernel.Basics.fudgeType
