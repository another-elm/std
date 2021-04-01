module Json.Internal exposing (..)

import Platform.Unstable.Effect as Effect


type Value
    = Value Effect.RawJsObject


unwrap : Value -> Effect.RawJsObject
unwrap (Value raw) =
    raw
