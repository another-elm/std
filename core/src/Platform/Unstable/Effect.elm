module Platform.Unstable.Effect exposing
    ( Runtime, RuntimeId, getId
    , Cmd(..)
    , EffectId, EffectSub(..), SubManagerId, SubPayload, OpaqueSubPayload, SubscriptionManager(..)
    , RawJsObject, Stepper, StepperBuilder, UpdateMetadata(..)
    )

{-| Unstable types and helper functions for working with effects in standard elm
modules.

@docs Runtime, RuntimeId, getId

@docs Cmd

@docs EffectId, EffectSub, SubManagerId, SubPayload, OpaqueSubPayload, SubscriptionManager

@docs RawJsObject, Stepper, StepperBuilder, UpdateMetadata

-}

import Basics exposing (Never)
import Elm.Kernel.Basics
import Maybe exposing (Maybe)
import Platform.Unstable.Impure as Impure
import Platform.Unstable.Task as RawTask
import String exposing (String)


{-| A `Sub` is conceptually a bunch of `SubPayload`s bundled together. Each
payload links to some Subscription Manager and a particular event that the
Subscription Manager is listening out for. The `SubPayload` also contains about
what the Subscription Manager should do (i.e. which `Msg` to send to an elm app
should that effect occur.)
-}
type alias SubPayload effectData payload msg =
    { managerId : SubManagerId
    , subId : String
    , effectData : effectData
    , onMessage : payload -> Maybe msg
    }


{-| Like a `SubPayload` but with some of the type variables fudged into stub
types so that they are hidden from the type signature.
-}
type alias OpaqueSubPayload msg =
    SubPayload Hidden Hidden msg


{-| The inner type of a `Sub`

This would be a `Sub` but the elm compiler gets the abdabs if
`Platform.Sub.Sub` is a type alias and not a type in its own right. Therefore,
`Sub` is a newtype around this.

-}
type EffectSub msg
    = EffectSub (List (SubPayload Hidden Hidden msg))


{-| The inner type of a `Cmd`

See [`EffectSub`](#EffectSub) for why `Cmd` cannot be a type alias.

-}
type Cmd msg
    = Cmd (List (RuntimeId -> RawTask.Task Never (Maybe msg)))


{-| An opaque reference to an Subscription Manager.

TODO(harry): gibe example

-}
type SubManagerId
    = SubManagerId SubManagerId


{-| An opaque reference to an Effect.

An example of an Effect is an event listener created for `Browser.Events.on`.

-}
type EffectId
    = EffectId EffectId


{-| The ingredients needed to construct a Subscription Manager.

TODO(harry): describe the difference between `EventListener` and
`RuntimeHandler`.

-}
type SubscriptionManager effectData payload
    = EventListener
        { discontinued : Impure.Function EffectId ()
        , new : effectData -> Impure.Function (Impure.Function payload ()) EffectId
        }
    | RuntimeHandler


{-| Reference to this app's runtime.

Kernel code can use this to work with effects.

-}
type Runtime msg
    = Runtime (Runtime msg)


{-| A slightly more limited version of `Runtime`.

Uses in contexts where we do not know the `msg` type of the app.

-}
type RuntimeId
    = RuntimeId RuntimeId


{-| Actually a js object.

Can only be meaningfully used by kernel code.

-}
type RawJsObject
    = RawJsObject RawJsObject


{-| The functions used by the elm runtime to do any thing impure based on the
current model.

For example render the view to the DOM.

-}
type alias Stepper model =
    model -> UpdateMetadata -> Impure.Action ()


{-| A function the "builds" a stepper.

Uses a `Runtime`, whatever object the user passes to `Elm.Main.init`, and
the first model (the one returned by `init`) to create a stepper.

-}
type alias StepperBuilder model appMsg =
    Runtime appMsg -> RawJsObject -> model -> Impure.Action (Stepper model)


{-| AsyncUpdate is default I think

TODO(harry) understand this by reading source of VirtualDom

-}
type UpdateMetadata
    = SyncUpdate
    | AsyncUpdate


type Hidden
    = Hidden Hidden


{-| Convert a `Runtime` into a `RuntimeId`.
-}
getId : Runtime msg -> RuntimeId
getId =
    Elm.Kernel.Basics.fudgeType
