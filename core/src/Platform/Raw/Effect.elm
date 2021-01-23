module Platform.Raw.Effect exposing
    ( Cmd(..)
    , EffectId
    , Hidden
    , HiddenConvertedSubType
    , Runtime
    , RuntimeId
    , EffectSub(..)
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
import String exposing (String)


type alias SubPayload effectData payload msg =
    { managerId : SubManagerId
    , subId : String
    , effectData : effectData
    , onMessage : payload -> msg
    }


type EffectSub msg
    = EffectSub (List (SubPayload Hidden Hidden msg))


type Cmd msg
    = Cmd (List (RuntimeId -> RawTask.Task Never (Maybe msg)))


type SubManagerId
    = SubManagerId SubManagerId


type EffectId
    = EffectId EffectId


type SubscriptionManager effectData payload
    = EventListener
        { discontinued : Impure.Function EffectId ()
        , new : effectData -> Impure.Function (Impure.Function payload ()) EffectId
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
