module Platform.Raw.Impure exposing
    ( Action, resolve, andThen, map
    , Function, fromFunction, toFunction
    )

{-| This module contains an abstaction for functions that **do things** when
they are run.

Why can we not use Task's to represent impure actions, given that this is
_exactly_ what they are for. Well, two reasons:

1.  Sometimes we need a guarantee that the function will be run exactly when we
    need to run. Task are always enqueued; they are only run after stepping
    through all the previous Tasks in the queue. Sometimes, for instance when
    updating the listeners for a subscription effect, this is not acceptable.

2.  We need to use impure functions to run Tasks. The
    `Platform.Raw.Scheduler.enqueue` function takes a Task, adds it to the
    scheduler queue and, if the scheduler is not currently stepping tasks (i.e.
    this is not a reentrant call to `Platform.Raw.Scheduler.enqueue`), starts
    stepping. This function is impure. However, if we represented it as a Task
    we would have an infinite loop! Instead we represent `enqueue` as an elm
    function returning an action.

This should become the cornerstone upon which Tasks and the scheduler is built.
The Function type is most useful for kernel interop but within elm it is a bit
clunky. Chaining Functions gets really messy and the code is impossible to
read. Therefore, we have the Action type alias: this encapsulates the impurity
and removes the awkward dependancy on the input. This alias is much nicer to
use within elm. A classic example of the most minimal design being best.


## Actions

@docs Action, resolve, andThen, map


## Functions

@docs Function, fromFunction, toFunction

-}

import Elm.Kernel.Basics


{-| Is actually just a function.

Kernel interop: We type fudge so that js can treat impure functions identically
to normal functions.

-}
type Function a b
    = Function__


{-| When an action is run it will produce a value of type b. Running the action
may cause side effects.

Kernel interop: A type alias so that kernel code can use a regular function
here.

-}
type alias Action b =
    Function () b


{-| Create an action that produces a value. Running it will have no side
effects.
-}
resolve : b -> Action b
resolve b =
    wrapFunction (\() -> b)


{-| Chain two actions.
-}
andThen : (a -> Action b) -> Action a -> Action b
andThen func action =
    wrapFunction
        (\() ->
            let
                a =
                    unwrapFunction action ()

                b =
                    unwrapFunction (func a) ()
            in
            b
        )


{-| Map the value produced by an action.
-}
map : (a -> b) -> Action a -> Action b
map mapper =
    andThen (\x -> resolve (mapper x))


{-| Convert a `Function` into an `Action` by partially applying `a` as its
first argument. Running the returned `Action` will call the input `Function`.
-}
fromFunction : Function a b -> a -> Action b
fromFunction f a =
    wrapFunction (\() -> unwrapFunction f a)


{-| Convert an `Action` into a `Function`.
-}
toFunction : (a -> Action b) -> Function a b
toFunction getAction =
    wrapFunction (\a -> unwrapFunction (getAction a) ())



-- Kernel interop --


unwrapFunction : Function a b -> (a -> b)
unwrapFunction =
    Elm.Kernel.Basics.fudgeType


wrapFunction : (a -> b) -> Function a b
wrapFunction =
    Elm.Kernel.Basics.fudgeType
