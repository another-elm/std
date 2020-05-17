module Platform.Raw.Cmd exposing  (RawCmd, RunttimeId)

import Platform


type RuntimeId = RuntimeId

type alias RawSub msg =
    List (RuntimeId -> Platform.Task Never (Maybe msg))
