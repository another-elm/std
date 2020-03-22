module Platform.Effects exposing (command)

import Basics exposing (..)
import Debug
import Elm.Kernel.Platform
import Maybe exposing (Maybe(..))
import Platform
import Platform.Channel as Channel
import Platform.Cmd as Cmd exposing (Cmd)


command : (Channel.Sender msg -> Platform.Task Never ()) -> Cmd msg
command function =
    Elm.Kernel.Platform.leaf "000PlatformEffect" function


mapCommand : (a -> b) -> (Channel.Sender a -> Platform.Task Never ()) -> (Channel.Sender b -> Platform.Task Never ())
mapCommand tagger function =
    \channel -> function (Channel.mapSender tagger channel)
