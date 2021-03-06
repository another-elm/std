module Platform.Unstable.Effect2 exposing (UpdateMetadata(..))

{-| It is not clear to me why this needs to exist.

Without this (and the import in the Platform kernel module) we get a ICE.

-}


type UpdateMetadata
    = SyncUpdate
    | AsyncUpdate
