module Util.Http exposing (actOnHttpResponse)

import Http
import Util.Cmds


actOnHttpResponse : Result Http.Error String -> Cmd never
actOnHttpResponse resp =
    case resp of
        Ok str ->
            Util.Cmds.write str

        Err (Http.BadUrl str) ->
            Util.Cmds.error [ "Bad Url", str ]

        Err Http.Timeout ->
            Util.Cmds.error [ "Timeout" ]

        Err Http.NetworkError ->
            Util.Cmds.error [ "NetworkError" ]

        Err (Http.BadStatus i) ->
            Util.Cmds.error [ "BadStatus", String.fromInt i ]

        Err (Http.BadBody str) ->
            Util.Cmds.error [ "BadBody", str ]
