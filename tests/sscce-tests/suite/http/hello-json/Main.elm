module Main exposing (main)

import Http
import Platform
import Json.Encode
import Json.Decode
import Util.Http
import Util.Cmds
import Util.Programs exposing (SuiteFlags)


getBook : String -> String -> Cmd (Result Http.Error String)
getBook protocol url =
    Http.get
        { url = protocol ++ url ++ "/some/json/endpoint"
        , expect = Http.expectJson identity Json.Decode.value
        }
        |> Cmd.map (Result.map (Json.Encode.encode 0))


update msg () =
    ( ()
    , Util.Http.actOnHttpResponse msg
    )


main : Platform.Program (SuiteFlags {}) () (Result Http.Error String)
main =
    Platform.worker
        { init = \{ suite } -> ( (), getBook suite.protocol suite.url )
        , update = update
        , subscriptions = \() -> Sub.none
        }
