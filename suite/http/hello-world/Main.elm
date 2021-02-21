module Main exposing (main)

import Http
import Platform
import Util.Cmds
import Util.Http
import Util.Programs exposing (SuiteFlags)


getBook : String -> String -> Cmd (Result Http.Error String)
getBook protocol url =
    Http.get
        { url = protocol ++ url ++ "/some/http/endpoint"
        , expect = Http.expectString identity
        }


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
