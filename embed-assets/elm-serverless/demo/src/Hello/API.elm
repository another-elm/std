port module Hello.API exposing (main)

import Serverless
import Serverless.Conn exposing (respond)
import Serverless.Conn.Body as Body


{-| This is the "hello world" of elm-serverless.

Most functionality has been disabled, by opting-out with the
`Serverless.no...` constructors

-}
main : Serverless.Program () () () ()
main =
    Serverless.httpApi
        { configDecoder = Serverless.noConfig
        , initialModel = ()
        , parseRoute = Serverless.noRoutes
        , update = Serverless.noSideEffects
        , interopPorts = Serverless.noPorts

        -- Entry point for new connections.
        , endpoint = respond ( 200, Body.text "Hello Elm on AWS Lambda" )

        -- Provides ports to the framework which are used for requests,
        -- and responses. Do not use these ports directly, the framework
        -- handles associating messages to specific connections with
        -- unique identifiers.
        , requestPort = requestPort
        , responsePort = responsePort
        }


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg
