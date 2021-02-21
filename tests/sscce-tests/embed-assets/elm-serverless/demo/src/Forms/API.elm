port module Forms.API exposing (main)

import Json.Decode exposing (Decoder, decodeValue, errorToString, int, map, string, succeed)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import Serverless
import Serverless.Conn exposing (method, request, respond)
import Serverless.Conn.Body as Body
import Serverless.Conn.Request exposing (Method(..), body)


{-| Shows one way to convert a JSON POST body into Elm data
-}
main : Serverless.Program () () () ()
main =
    Serverless.httpApi
        { configDecoder = Serverless.noConfig
        , initialModel = ()
        , parseRoute = Serverless.noRoutes
        , update = Serverless.noSideEffects
        , requestPort = requestPort
        , responsePort = responsePort
        , interopPorts = Serverless.noPorts

        -- Entry point for new connections.
        , endpoint = endpoint
        }


type alias Person =
    { name : String
    , age : Int
    }


endpoint : Conn -> ( Conn, Cmd () )
endpoint conn =
    let
        decodeResult val =
            decodeValue personDecoder val |> Result.mapError errorToString

        result =
            conn |> request |> body |> Body.asJson |> Result.andThen decodeResult
    in
    case ( method conn, result ) of
        ( POST, Ok person ) ->
            respond ( 200, Body.text <| Encode.encode 0 (personEncoder person) ) conn

        ( POST, Err err ) ->
            respond
                ( 400
                , Body.text <| "Could not decode request body. " ++ err
                )
                conn

        _ ->
            respond ( 405, Body.text "Method not allowed" ) conn


personDecoder : Decoder Person
personDecoder =
    succeed Person
        |> required "name" string
        |> required "age" int


personEncoder : Person -> Encode.Value
personEncoder person =
    [ ( "name", Encode.string person.name )
    , ( "age", Encode.int person.age )
    ]
        |> Encode.object


type alias Conn =
    Serverless.Conn.Conn () () () ()


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg
