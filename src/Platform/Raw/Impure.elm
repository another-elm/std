module Platform.Raw.Impure exposing (Function, Function2, Function3, andThen, function,map, run, unwrapFunction, xx2, xx42, toThunk)

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
import Elm.Kernel.Basics


{-| Is actually just a function. We type fudge so that js can treat impure
functions identically to normal functions.
-}
type Function a b
    = Function


type alias Function2 a b c =
    Function a (Function b c)


type alias Function3 a b c d =
    Function2 a  b (Function c d)


function : (a -> b) -> Function a b
function =
    Elm.Kernel.Basics.fudgeType


andThen : Function b c -> Function a b -> Function a c
andThen ip2 ip1  =
    function
        (\a ->
            let
                b =
                    unwrapFunction ip1 a
            in
            unwrapFunction ip2 b
        )

map : (b -> c) -> Function a b -> Function a c
map mapper ip =
    function
        (\a ->
            let
                b =
                    unwrapFunction ip a
            in
            mapper b
        )


unwrapFunction : Function a b -> (a -> b)
unwrapFunction =
    Elm.Kernel.Basics.fudgeType


run : a -> Function a b -> b
run x f =
    unwrapFunction f x


xx2 : Function a b -> (c -> a) -> Function c b
xx2 f g =
    function
        (\x ->
            unwrapFunction
                f
                (g x)
        )


xx42 : (a -> Function () b) -> Function a b
xx42 f =
    function
        (\x ->
            unwrapFunction
                (f x)
                ()
        )

toThunk : a -> Function a b -> Function () b
toThunk x f =
    function (\() -> x)
        |> andThen f
