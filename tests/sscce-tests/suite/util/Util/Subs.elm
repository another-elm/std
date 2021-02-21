port module Util.Subs exposing (read)


port read : (String -> msg) -> Sub msg
