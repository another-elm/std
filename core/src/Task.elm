module Task exposing
    ( Task, perform, attempt
    , andThen, succeed, fail, sequence
    , map, map2, map3, map4, map5
    , onError, mapError
    )

{-| Tasks make it easy to describe asynchronous operations that may fail, like
HTTP requests or writing to a database.


# Tasks

@docs Task, perform, attempt


# Chains

@docs andThen, succeed, fail, sequence


# Maps

@docs map, map2, map3, map4, map5


# Errors

@docs onError, mapError

-}

import Basics exposing ((<<), (>>), (|>), Never, never)
import Elm.Kernel.Platform
import List exposing ((::))
import Maybe exposing (Maybe(..))
import Platform
import Platform.Cmd exposing (Cmd)
import Platform.Raw.Effect as Effect
import Platform.Raw.Task as RawTask
import Platform.Scheduler as Scheduler
import Result exposing (Result(..))


{-| Here are some common tasks:

  - [`now : Task x Posix`][now]
  - [`focus : String -> Task Error ()`][focus]
  - [`sleep : Float -> Task x ()`][sleep]

[now]: /packages/elm/time/latest/Time#now
[focus]: /packages/elm/browser/latest/Browser-Dom#focus
[sleep]: /packages/elm/core/latest/Process#sleep

In each case we have a `Task` that will resolve successfully with an `a` value
or unsuccessfully with an `x` value. So `Browser.Dom.focus` we may fail with an
`Error` if the given ID does not exist. Whereas `Time.now` never fails so
I cannot be more specific than `x`. No such value will ever exist! Instead it
always succeeds with the current POSIX time.

More generally a task is a _description_ of what you need to do. Like a todo
list. Or like a grocery list. Or like GitHub issues. So saying "the task is
to tell me the current POSIX time" does not complete the task! You need
[`perform`](#perform) tasks or [`attempt`](#attempt) tasks.

-}
type alias Task x a =
    Platform.Task x a



-- BASICS


{-| A task that succeeds immediately when run. It is usually used with
[`andThen`](#andThen). You can use it like `map` if you want:

    import Time


    -- elm install elm/time
    timeInMillis : Task x Int
    timeInMillis =
        Time.now
            |> andThen (\t -> succeed (Time.posixToMillis t))

-}
succeed : a -> Task x a
succeed =
    Ok >> RawTask.Value >> Scheduler.wrapTask


{-| A task that fails immediately when run. Like with `succeed`, this can be
used with `andThen` to check on the outcome of another task.

    type Error
        = NotFound

    notFound : Task Error a
    notFound =
        fail NotFound

-}
fail : x -> Task x a
fail =
    Err >> RawTask.Value >> Scheduler.wrapTask



-- MAPPING


{-| Transform a task. Maybe you want to use [`elm/time`][time] to figure
out what time it will be in one hour:

    import Task exposing (Task)
    import Time


    -- elm install elm/time
    timeInOneHour : Task x Time.Posix
    timeInOneHour =
        Task.map addAnHour Time.now

    addAnHour : Time.Posix -> Time.Posix
    addAnHour time =
        Time.millisToPosix (Time.posixToMillis time + 60 * 60 * 1000)

[time]: /packages/elm/time/latest/

-}
map : (a -> b) -> Task x a -> Task x b
map func taskA =
    taskA
        |> andThen (\a -> succeed (func a))


{-| Put the results of two tasks together. For example, if we wanted to know
the current month, we could use [`elm/time`][time] to ask:

    import Task exposing (Task)
    import Time


    -- elm install elm/time
    getMonth : Task x Int
    getMonth =
        Task.map2 Time.toMonth Time.here Time.now

**Note:** Say we were doing HTTP requests instead. `map2` does each task in
order, so it would try the first request and only continue after it succeeds.
If it fails, the whole thing fails!

[time]: /packages/elm/time/latest/

-}
map2 : (a -> b -> result) -> Task x a -> Task x b -> Task x result
map2 func taskA taskB =
    taskA
        |> andThen
            (\a ->
                taskB
                    |> andThen (\b -> succeed (func a b))
            )


{-| -}
map3 : (a -> b -> c -> result) -> Task x a -> Task x b -> Task x c -> Task x result
map3 func taskA taskB taskC =
    taskA
        |> andThen
            (\a ->
                taskB
                    |> andThen
                        (\b ->
                            taskC
                                |> andThen (\c -> succeed (func a b c))
                        )
            )


{-| -}
map4 : (a -> b -> c -> d -> result) -> Task x a -> Task x b -> Task x c -> Task x d -> Task x result
map4 func taskA taskB taskC taskD =
    taskA
        |> andThen
            (\a ->
                taskB
                    |> andThen
                        (\b ->
                            taskC
                                |> andThen
                                    (\c ->
                                        taskD
                                            |> andThen (\d -> succeed (func a b c d))
                                    )
                        )
            )


{-| -}
map5 : (a -> b -> c -> d -> e -> result) -> Task x a -> Task x b -> Task x c -> Task x d -> Task x e -> Task x result
map5 func taskA taskB taskC taskD taskE =
    taskA
        |> andThen
            (\a ->
                taskB
                    |> andThen
                        (\b ->
                            taskC
                                |> andThen
                                    (\c ->
                                        taskD
                                            |> andThen
                                                (\d ->
                                                    taskE
                                                        |> andThen (\e -> succeed (func a b c d e))
                                                )
                                    )
                        )
            )


{-| Start with a list of tasks, and turn them into a single task that returns a
list. The tasks will be run in order one-by-one and if any task fails the whole
sequence fails.

    sequence [ succeed 1, succeed 2 ] == succeed [ 1, 2 ]

-}
sequence : List (Task x a) -> Task x (List a)
sequence tasks =
    List.foldr (map2 (::)) (succeed []) tasks



-- CHAINING


{-| Chain together a task and a callback. The first task will run, and if it is
successful, you give the result to the callback resulting in another task. This
task then gets run. We could use this to make a task that resolves an hour from
now:

    -- elm install elm/time


    import Process
    import Time

    timeInOneHour : Task x Time.Posix
    timeInOneHour =
        Process.sleep (60 * 60 * 1000)
            |> andThen (\_ -> Time.now)

First the process sleeps for an hour **and then** it tells us what time it is.

-}
andThen : (a -> Task x b) -> Task x a -> Task x b
andThen func =
    Scheduler.unwrapTask
        >> RawTask.andThen
            (\r ->
                case r of
                    Ok val ->
                        Scheduler.unwrapTask (func val)

                    Err e ->
                        RawTask.Value (Err e)
            )
        >> Scheduler.wrapTask



-- ERRORS


{-| Recover from a failure in a task. If the given task fails, we use the
callback to recover.

    fail "file not found"
      |> onError (\msg -> succeed 42)
      -- succeed 42

    succeed 9
      |> onError (\msg -> succeed 42)
      -- succeed 9

-}
onError : (x -> Task y a) -> Task x a -> Task y a
onError func =
    Scheduler.unwrapTask
        >> RawTask.andThen
            (\r ->
                case r of
                    Ok val ->
                        RawTask.Value (Ok val)

                    Err e ->
                        Scheduler.unwrapTask (func e)
            )
        >> Scheduler.wrapTask


{-| Transform the error value. This can be useful if you need a bunch of error
types to match up.

    type Error
        = Http Http.Error
        | WebGL WebGL.Error

    getResources : Task Error Resource
    getResources =
        sequence
            [ mapError Http serverTask
            , mapError WebGL textureTask
            ]

-}
mapError : (x -> y) -> Task x a -> Task y a
mapError convert task =
    task
        |> onError (fail << convert)



-- COMMANDS


type MyCmd msg
    = Perform (Task Never msg)


{-| Like I was saying in the [`Task`](#Task) documentation, just having a
`Task` does not mean it is done. We must command Elm to `perform` the task:

    -- elm install elm/time


    import Task
    import Time

    type Msg
        = Click
        | Search String
        | NewTime Time.Posix

    getNewTime : Cmd Msg
    getNewTime =
        Task.perform NewTime Time.now

If you have worked through [`guide.elm-lang.org`][guide] (highly recommended!)
you will recognize `Cmd` from the section on The Elm Architecture. So we have
changed a task like "make delicious lasagna" into a command like "Hey Elm, make
delicious lasagna and give it to my `update` function as a `Msg` value."

[guide]: https://guide.elm-lang.org/

-}
perform : (a -> msg) -> Task Never a -> Cmd msg
perform toMessage task =
    performHelp (map toMessage task)


{-| This is very similar to [`perform`](#perform) except it can handle failures!
So we could _attempt_ to focus on a certain DOM node like this:

    -- elm install elm/browser


    import Browser.Dom
    import Task

    type Msg
        = Click
        | Search String
        | Focus (Result Browser.DomError ())

    focus : Cmd Msg
    focus =
        Task.attempt Focus (Browser.Dom.focus "my-app-search-box")

So the task is "focus on this DOM node" and we are turning it into the command
"Hey Elm, attempt to focus on this DOM node and give me a `Msg` about whether
you succeeded or failed."

**Note:** Definitely work through [`guide.elm-lang.org`][guide] to get a
feeling for how commands fit into The Elm Architecture.

[guide]: https://guide.elm-lang.org/

-}
attempt : (Result x a -> msg) -> Task x a -> Cmd msg
attempt resultToMessage task =
    performHelp
        (task
            |> andThen (succeed << resultToMessage << Ok)
            |> onError (succeed << resultToMessage << Err)
        )


performHelp : Task Never msg -> Cmd msg
performHelp task =
    command (\_ -> map Just task)



-- Kernel interop --


command : (Effect.RuntimeId -> Platform.Task Never (Maybe msg)) -> Cmd msg
command =
    Elm.Kernel.Platform.command
