module Platform.Raw.Effect exposing
    ( Cmd(..)
    , HiddenConvertedSubType
    , Runtime
    , RuntimeId
    , Sub(..)
    , SubId
    , getId
    )

import Basics exposing (Never)
import Elm.Kernel.Basics
import Maybe exposing (Maybe)
import Platform.Raw.Task as RawTask


{-| When making changes to this type grep for HiddenConvertedSubType,
_Platform_subscription and Platform.subscription.
-}
type Sub msg
    = Sub (List ( SubId, HiddenConvertedSubType -> Maybe msg ))


type Cmd msg
    = Cmd (List (RuntimeId -> RawTask.Task Never (Maybe msg)))


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
