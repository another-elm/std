module Platform.Raw.Effect exposing
    ( HiddenConvertedSubType
    , RawSub
    , Runtime
    , RuntimeId
    , SubId
    , getId
    )

import Elm.Kernel.Basics
import Maybe exposing (Maybe)


{-| When making changes to this type grep for HiddenConvertedSubType,
_Platform_subscription and Platform.subscription.
-}
type alias RawSub msg =
    List ( SubId, HiddenConvertedSubType -> Maybe msg )


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
