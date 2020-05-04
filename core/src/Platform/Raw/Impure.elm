module Platform.Raw.Impure exposing (Function, andThen, fromPure, map, propagate, unwrapFunction)

{-| This module contains an abstaction for functions that **do things** when
they are run. The functions in this module are constrained to take one argument.

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

Hopefully, use of this module can be reduced to a couple of key places and
maybe even inlined into the scheduler is that is the only place that uses it.
Hopefully, it will help us move all effectful functions out of elm.

-}

import Basics exposing ((|>))
import Debug
import Elm.Kernel.Basics


{-| Is actually just a function. We type fudge so that js can treat impure
functions identically to normal functions.
-}
type Function a b
    = Function


fromPure : (a -> b) -> Function a b
fromPure =
    Elm.Kernel.Basics.fudgeType


andThen : Function b c -> Function a b -> Function a c
andThen ip2 ip1 =
    let
        f1 =
            unwrapFunction ip1

        f2 =
            unwrapFunction ip2
    in
    fromPure (\a -> f2 (f1 a))


map : (b -> c) -> Function a b -> Function a c
map mapper =
    andThen (fromPure mapper)


unwrapFunction : Function a b -> (a -> b)
unwrapFunction =
    Elm.Kernel.Basics.fudgeType


{-| Given an (pure) function that creates an impure function from some input
and the input that the created impure function needs create a new impure
function.
-}
propagate : (a -> Function b c) -> b -> Function a c
propagate f b =
    fromPure (\a -> unwrapFunction (f a) b)
