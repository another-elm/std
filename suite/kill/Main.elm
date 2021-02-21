module Main exposing (main)

{-| This is not a good test; it will either succeed or go into an infinite
loop.

However, I cannot think of any other way to test `Process.kill`
-}

import Platform
import Process
import Task exposing (Task)
import Util.Cmds


type Msg
    = Kill Process.Id
    | Done


neverEndingTask : () -> Task Never Never
neverEndingTask () =
    Process.sleep 10
        |> Task.andThen (\() -> neverEndingTask ())


init : ( (), Cmd Msg )
init =
    ( ()
    , Task.perform Kill (Process.spawn (neverEndingTask ()))
    )


update : Msg -> () -> ( (), Cmd Msg )
update msg () =
    case msg of
        Kill id->
            ( ()
            , Task.perform (\() -> Done) (Process.kill id)
            )

        Done ->
            ( ()
            , Util.Cmds.write "done"
            )


main : Platform.Program () () Msg
main =
    Platform.worker
        { init = \() -> init
        , update = update
        , subscriptions = \_ -> Sub.none
        }
