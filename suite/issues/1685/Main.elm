port module Main exposing (main)


import Platform
import Util.Programs


type alias TrickyNames =
  { static : Int
  , default : Int
  , interface : Int
  , arguments : Int
  , this : Int
  , prototype : Int
  }


port echo : TrickyNames -> Cmd msg


main : Program () () ()
main =
    Util.Programs.sendCmd (echo (TrickyNames 0 1 2 3 4 5))
