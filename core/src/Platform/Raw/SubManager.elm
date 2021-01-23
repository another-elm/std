module Platform.Raw.SubManager exposing (subscriptionManager)


import Elm.Kernel.Basics
import Basics exposing (..)
import Elm.Kernel.Platform
import Platform.Raw.Effect exposing (EffectId, EffectSub(..), Hidden, SubManagerId, SubPayload, SubscriptionManager(..))
import Platform.Raw.Impure as Impure
import String exposing (String)
import Platform.Sub exposing (Sub(..))


subscriptionManager :
    SubscriptionManager effectData payload
    -> (effectData -> String)
    -> ( effectData -> (payload -> msg) -> Sub msg, SubManagerId )
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
