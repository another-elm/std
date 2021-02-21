module Main exposing (main)

import Json.Encode
import Json.Value
import Platform
import Util.Programs


jsonValue : Json.Value.JsonValue
jsonValue =
    Json.Value.NumericValue 0.5


toWrite : String
toWrite =
    jsonValue
        |> Json.Value.encode
        |> Json.Encode.encode 1


main : Platform.Program () () ()
main =
    Util.Programs.print toWrite
