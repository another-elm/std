module Platform.Raw.SubManager exposing (subscriptionManager)

import Basics exposing (..)
import Elm.Kernel.Basics
import Elm.Kernel.Platform
import Maybe exposing (Maybe)
import Platform.Raw.Effect exposing (EffectId, EffectSub(..), Hidden, SubManagerId, SubPayload, SubscriptionManager(..))
import Platform.Raw.Impure as Impure
import Platform.Sub exposing (Sub(..))
import String exposing (String)


subscriptionManager :
    SubscriptionManager effectData payload
    -> (effectData -> String)
    -> ( effectData -> (payload -> Maybe msg) -> Sub msg, SubManagerId )
subscriptionManager onSubUpdate serialize =
    let
        managerId =
            case onSubUpdate of
                EventListener el ->
                    registerEventSubscriptionListener el

                RuntimeHandler ->
                    registerRuntimeSubscriptionHandler ()
    in
    ( \effectData onMsg ->
        [ makeSubPayload
            { managerId = managerId
            , subId = serialize effectData
            , effectData = effectData
            , onMessage = onMsg
            }
        ]
            |> EffectSub
            |> Sub
    , managerId
    )


makeSubPayload : SubPayload effectData payload msg -> SubPayload Hidden Hidden msg
makeSubPayload =
    Elm.Kernel.Basics.fudgeType


registerEventSubscriptionListener :
    { discontinued : Impure.Function EffectId ()
    , new : subId -> Impure.Function (Impure.Function payload ()) EffectId
    }
    -> SubManagerId
registerEventSubscriptionListener =
    Elm.Kernel.Platform.registerEventSubscriptionListener


registerRuntimeSubscriptionHandler :
    ()
    -> SubManagerId
registerRuntimeSubscriptionHandler =
    Elm.Kernel.Platform.registerRuntimeSubscriptionHandler
