module Platform.Raw.SubManager exposing (subscriptionManager)

import Elm.Kernel.Basics
import Elm.Kernel.Platform
import Platform.Raw.Effect exposing (..)
import Platform.Raw.Impure as Impure


subscriptionManager :
    SubscriptionManager subId payload
    -> ( subId -> (payload -> msg) -> Sub msg, SubManagerId )
subscriptionManager onSubUpdate =
    let
        managerId =
            case onSubUpdate of
                EventListener el ->
                    registerEventSubscriptionListener el

                RuntimeHandler ->
                    registerRuntimeSubscriptionHandler ()
    in
    ( \subId onMsg ->
        Sub
            [ makeSubPayload
                { managerId = managerId
                , subId = subId
                , onMessage = onMsg
                }
            ]
    , managerId
    )


makeSubPayload : SubPayload subId payload msg -> SubPayload Hidden Hidden msg
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
