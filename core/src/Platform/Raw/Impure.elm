module Platform.Raw.Impure exposing
    ( Action, andThen, map
    , Function, unwrapFunction, wrapFunction
    , fromFunction, toFunction, fromPure, fromThunk
    )

{-| This module contains an abstaction for functions that **do things** when
they are run. The functions in this module are constrained to take one
argument.

Why can we not use Task's for this, given that this is _exactly_ what they are
intended for. Well, two reasons

1.  Sometimes we need a guarantee that the function will be run exactly when we
    need to run. Task are always enqueued; they are only run after stepping
    through all the previous Tasks in the queue. Sometimes, this is not
    acceptable, for instance when updating the listeners for a subscription
    effect.

2.  We need to use impure functions to run Tasks. The
    `Platform.Raw.Scheduler.enqueue` function takes a Task, adds it to the
    scheduler queue and, if the scheduler is not currently stepping tasks (i.e.
    this is not a reentrant call to `Platform.Raw.Scheduler.enqueue`), starts
    stepping. This function is impure. However, if we represented it as a Task
    we would have an infinite loop!

This should become the cornerstone upon which Tasks and the scheduler is built.
The Function type is most useful for kernel interop but within elm it is a bit
clunky. Chaining Functions gets really messy and the code is impossible to
read. Therefore, we have the Action type alias: this encapsulates the impurity
and removes the awkward dependancy on the input. This alias is much nicer to
use within elm. A classic example of the most minimal design being best.


# Actions

@docs Action, andThen, map


# Functions

@docs Function, unwrapFunction, wrapFunction


# Conversions

@docs fromFunction, toFunction, fromPure, fromThunk

-}

import Basics exposing ((|>))
import Debug
import Elm.Kernel.Basics


{-| Is actually just a function. We type fudge so that js can treat impure
functions identically to normal functions.
-}
type Function a b
    = Function__


{-| Kernel interop: A type alias so that kernel code can use a regular function
here.
-}
type alias Action b =
    Function () b


fromPure : b -> Action b
fromPure b =
    fromThunk (\() -> b)


fromThunk : (() -> b) -> Action b
fromThunk f =
    wrapFunction f


andThen : (a -> Action b) -> Action a -> Action b
andThen func action =
    fromThunk
        (\() ->
            let
                a =
                    unwrapFunction action ()

                b =
                    unwrapFunction (func a) ()
            in
            b
        )


map : (a -> b) -> Action a -> Action b
map mapper =
    andThen (\x -> fromPure (mapper x))


fromFunction : Function a b -> a -> Action b
fromFunction f a =
    fromThunk (\() -> unwrapFunction f a)


toFunction : (a -> Action b) -> Function a b
toFunction getAction =
    wrapFunction (\a -> unwrapFunction (getAction a) ())


unwrapFunction : Function a b -> (a -> b)
unwrapFunction =
    Elm.Kernel.Basics.fudgeType


wrapFunction : (a -> b) -> Function a b
wrapFunction =
    Elm.Kernel.Basics.fudgeType
