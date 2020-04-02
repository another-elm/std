module Platform.Effects exposing (command)

import Basics exposing (..)
import Debug
import Elm.Kernel.Platform
import Maybe exposing (Maybe(..))
import Platform
import Platform.Scheduler as Scheduler
import Platform.Cmd as Cmd exposing (Cmd)


command : Platform.Task Never (Maybe msg) -> Cmd msg
command function =
    Elm.Kernel.Platform.leaf "000PlatformEffect" function


mapCommand : (a -> b) -> Platform.Task Never (Maybe a) -> Platform.Task Never (Maybe b)
mapCommand tagger task =
    Scheduler.andThen ((Maybe.map tagger) >> Scheduler.succeed) task
