module Main exposing (main)

import Platform
import Util.Programs

backSlashChar : Char
backSlashChar =
    '\\'

toWrite : String
toWrite =
    String.fromChar backSlashChar


main : Platform.Program () () ()
main =
    Util.Programs.print toWrite
