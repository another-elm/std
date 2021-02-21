module Quoted.API exposing (main, pipeline, router, update)

import Json.Encode as Encode
import Quoted.Middleware
import Quoted.Pipelines.Quote as Quote
import Quoted.Route exposing (Route(..), queryEncoder)
import Quoted.Types exposing (Config, Conn, Msg(..), Plug, configDecoder, requestPort, responsePort)
import Random
import Serverless
import Serverless.Conn exposing (mapUnsent, method, respond, route, updateResponse)
import Serverless.Conn.Body as Body
import Serverless.Conn.Request exposing (Method(..))
import Serverless.Plug as Plug exposing (plug)
import Url.Parser


{-| A Serverless.Program is parameterized by your 5 custom types

  - Config is a server load-time record of deployment specific values
  - Model is for whatever you need during the processing of a request
  - Route represents the set of routes your app will handle
  - Msg is your app message type

-}
main : Serverless.Program Config () Route Msg
main =
    Serverless.httpApi
        { initialModel = ()

        -- Decodes per instance configuration into Elm data. If decoding fails
        -- the server will fail to start. This decoder is called once at
        -- startup.
        , configDecoder = configDecoder

        -- Parses the request path and query string into Elm data.
        -- If parsing fails, a 404 is automatically sent.
        , parseRoute = Url.Parser.parse Quoted.Route.route

        -- Entry point for new connections.
        -- This function composition passes the conn through a pipeline and then
        -- into a router (but only if the conn is not sent by the pipeline).
        , endpoint = Plug.apply pipeline >> mapUnsent router

        -- Update function which operates on Conn.
        , update = update

        -- Provides ports to the framework which are used for requests,
        -- and responses. Do not use these ports directly, the framework
        -- handles associating messages to specific connections with
        -- unique identifiers.
        , requestPort = requestPort
        , responsePort = responsePort
        , interopPorts = Serverless.noPorts
        }


{-| Pipelines are chains of functions (plugs) which transform the connection.

These pipelines can optionally send a response through the connection early, for
example a 401 sent if authorization fails. Use Plug.apply to pass a connection
through a pipeline (see above). Note that Plug.apply will stop processing the
pipeline once the connection is sent.

-}
pipeline : Plug
pipeline =
    Plug.pipeline
        |> plug Quoted.Middleware.cors
        |> plug Quoted.Middleware.auth


{-| Just a big "case of" on the request method and route.

Remember that route is the request path and query string, already parsed into
nice Elm data, courtesy of the parseRoute function provided above.

-}
router : Conn -> ( Conn, Cmd Msg )
router conn =
    case
        ( method conn
        , route conn
        )
    of
        ( GET, Home query ) ->
            respond ( 200, Body.text <| (++) "Home: " <| Encode.encode 0 (queryEncoder query) ) conn

        ( _, Quote lang ) ->
            -- Delegate to Pipeline/Quote module.
            Quote.router lang conn

        ( GET, Number ) ->
            -- Generate a random number.
            ( conn
            , Random.generate RandomNumber <| Random.int 0 1000000000
            )

        ( GET, Buggy ) ->
            respond ( 500, Body.text "bugs, bugs, bugs" ) conn

        _ ->
            respond ( 405, Body.text "Method not allowed" ) conn


{-| The application update function.

Just like an Elm SPA, an elm-serverless app has a single update
function which handles messages resulting from side-effects.

-}
update : Msg -> Conn -> ( Conn, Cmd Msg )
update msg conn =
    case msg of
        -- This message is intended for the Pipeline/Quote module
        GotQuotes result ->
            Quote.gotQuotes result conn

        RandomNumber val ->
            respond ( 200, Body.json <| Encode.int val ) conn
