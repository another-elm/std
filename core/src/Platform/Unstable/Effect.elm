module Platform.Unstable.Effect exposing
    ( Cmd(..)
    , EffectId
    , EffectSub(..)
    , Hidden
    , HiddenConvertedSubType
    , RawJsObject
    , Runtime
    , RuntimeId
    , Stepper
    , StepperBuilder
    , SubManagerId
    , SubPayload
    , SubscriptionManager(..)
    , UpdateMetadata(..)
    , getId
    )

import Basics exposing (Never)
import Elm.Kernel.Basics
import Maybe exposing (Maybe)
import Platform.Unstable.Impure as Impure
import Platform.Unstable.Task as RawTask
import String exposing (String)


type alias SubPayload effectData payload msg =
    { managerId : SubManagerId
    , subId : String
    , effectData : effectData
    , onMessage : payload -> Maybe msg
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


type RawJsObject
    = RawJsObject RawJsObject


type alias StepperBuilder model appMsg =
    Runtime appMsg -> RawJsObject -> model -> Impure.Action (Stepper model)


{-| AsyncUpdate is default I think

TODO(harry) understand this by reading source of VirtualDom

-}
type UpdateMetadata
    = SyncUpdate
    | AsyncUpdate


type alias Stepper model =
    model -> UpdateMetadata -> Impure.Action ()


getId : Runtime msg -> RuntimeId
getId =
    Elm.Kernel.Basics.fudgeType
