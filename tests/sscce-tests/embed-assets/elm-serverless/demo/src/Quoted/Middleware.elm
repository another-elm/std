module Quoted.Middleware exposing (auth, cors)

{-| Middleware is just a simple function which transforms a connection.
-}

import Quoted.Types exposing (Conn)
import Serverless.Conn exposing (config, header, request, toSent, updateResponse)
import Serverless.Conn.Body as Body
import Serverless.Conn.Response exposing (addHeader, setBody, setStatus)


{-| Simple function to add some cors response headers
-}
cors :
    Serverless.Conn.Conn config model route msg
    -> Serverless.Conn.Conn config model route msg
cors conn =
    updateResponse
        (addHeader ( "access-control-allow-origin", "*" )
            >> addHeader ( "access-control-allow-methods", "GET,POST" )
         -- ...
        )
        conn


{-| Dumb auth just checks if auth header is present.

To demonstrate middleware which sends a response.

-}
auth : Conn -> Conn
auth conn =
    case
        ( config conn |> .enableAuth
        , header "authorization" conn
        )
    of
        ( True, Nothing ) ->
            conn
                |> updateResponse
                    (setStatus 401
                        >> setBody (Body.text "Authorization header not provided")
                    )
                |> toSent

        _ ->
            conn
