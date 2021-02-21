port module Util.Cmds exposing (error, write)


port write : String -> Cmd never


port error : List String -> Cmd never
