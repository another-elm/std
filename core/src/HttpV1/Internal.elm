module HttpV1.Internal exposing
    ( RawRequest
    , Request(..)
    )

import Basics exposing (..)
import Http
import Maybe exposing (Maybe)
import String exposing (String)


type Request e a
    = Request (RawRequest e a)


type alias RawRequest e a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , expect : Http.Resolver e a
    , timeout : Maybe Float
    , withCredentials : Bool
    }
