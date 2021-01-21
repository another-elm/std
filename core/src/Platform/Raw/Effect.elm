module Platform.Raw.Effect exposing
    ( Cmd(..)
    , EffectId
    , Hidden
    , HiddenConvertedSubType
    , Runtime
    , RuntimeId
    , Sub(..)
    , SubId
    , SubManagerId
    , SubPayload
    , SubscriptionManager(..)
    , getId
    )

import Basics exposing (Never)
import Elm.Kernel.Basics
import Maybe exposing (Maybe)
import Platform.Raw.Impure as Impure
import Platform.Raw.Task as RawTask


type alias SubPayload comparableSubId payload msg =
    { managerId : SubManagerId
    , subId : comparableSubId
    , onMessage : payload -> msg
    }


type Sub msg
    = Sub (List (SubPayload Hidden Hidden msg))


type Cmd msg
    = Cmd (List (RuntimeId -> RawTask.Task Never (Maybe msg)))


type SubId subId
    = SubId (SubId subId)


type SubManagerId
    = SubManagerId SubManagerId


type EffectId
    = EffectId EffectId


type SubscriptionManager subId payload
    = EventListener
        { discontinued : Impure.Function EffectId ()
        , new : subId -> Impure.Function (Impure.Function payload ()) EffectId
        }
    | RuntimeHandler


type HiddenConvertedSubType
    = HiddenConvertedSubType HiddenConvertedSubType


type Hidden
    = Hidden Hidden


type RuntimeId
    = RuntimeId RuntimeId


type Runtime msg
    = Runtime (Runtime msg)


getId : Runtime msg -> RuntimeId
getId =
    Elm.Kernel.Basics.fudgeType
