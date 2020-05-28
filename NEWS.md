# NEWS

A little inline blog documenting the development of this library.

## DRAFT -- Steppers

The `_Platform_initialize` function in the official
`elm/core:Elm.Kernel.Platform` module is defined like this:

```js
function _Platform_initialize(flagDecoder, args, init, update, subscriptions, stepperBuilder) {
   // ...
}
```

but what is the `stepperBuilder` parameter?

I will give you the following clues to work it out:

1. When creating a `elm/core:Platform.Worker` we pass the `initialize` function [this][stepper-worker] as its `stepperBuilder`:

   ```js
   function() { return function() {} }
   ```

2. `elm/core:Elm.Kernel.Platform.initialize` uses the `stepperBuilder` parameter like [this][init-builder]:

   ```js
   var stepper = stepperBuilder(sendToApp, model);
   ```

   and then uses the created `stepper` like [this][init-stepper] with in the `sendToApp` function:

   ```js
   stepper(model = pair.a, viewMetadata);
   ```

3. When creating a HTML element, `elm/browser:Elm.Kernel.Browser.element` passes [this monster][stepper-element] as its `stepperBuilder`:

   ```js
   function(sendToApp, initialModel) {
      var view = impl.__$view;
      /**__PROD/
      var domNode = args['node'];
      //*/
      /**__DEBUG/
      var domNode = args && args['node'] ? args['node'] : __Debug_crash(0);
      //*/
      var currNode = _VirtualDom_virtualize(domNode);

      return _Browser_makeAnimator(initialModel, function(model)
      {
         var nextNode = view(model);
         var patches = __VirtualDom_diff(currNode, nextNode);
         domNode = __VirtualDom_applyPatches(domNode, currNode, patches, sendToApp);
         currNode = nextNode;
      });
   }
   ```

Figured it out? I doubt it. Given my three clues I think all we can work out
that complex code without static typing quickly becomes an unintelligible mess
that is very hard to read or maintain.

### A small step for a man

A `stepperBuilder` "builds" a stepper. If were trying to rewrite the runtime in
elm we might have&nbsp;[[1]](####1):

```elm
type alias StepperBuilder =
      SendToApp msg -> model -> Stepper model
```

We can say that `StepperBuilder` takes a `SendToApp` and the initial model and
creates `Stepper`. It is very important to note that this function **is not
pure**. When you call `stepperBuilder` stuff may happen (concretely the runtime
renders your initial view and draws it to the DOM).

"What is `Stepper` and what is `SendToApp msg`?" I hear you ask. Well:

```elm
type alias Stepper model =
      model -> ViewMetadata -> ()

type alias SendToApp msg =
      msg -> ViewMetadata -> ()
```

So `Stepper` takes a value of model and some `ViewMetadata` and returns
nothing! We know that `Stepper` must be an impure function otherwise this is
pointless. In practice the elm runtime will call this `Stepper` every time the
model updates and `Stepper` will update the DOM accordingly.

Yet there is  another type: `ViewMetadata`! Before you ask "What is `Stepper`?" I must confess that I do not really know. It controls whether the runtime instantly renders changes to the DOM or queues them using `requestAnimationFrame`. I believe it is the key to the solution to the issues in elm `0.18` where port subscriptions would sometimes fire before the DOM had been updated and other times they would not fire instantly in response to DOM events. For now, we can make `ViewMetadata` an placeholder type and fill it in later when I have a better idea about what is going on.

```elm
type ViewMetadata
   = ViewMetadata ViewMetadata
```

Finally we come to `SendToApp`. The DOM can produce events which need to be
passed to the applications `update` function. The runtime gives the
`StepperBuilder` the `SendToApp` function to do just that. Event listeners
attached to the DOM should call `SendToApp` with a message (and a value for the
mysterious `ViewMetadata`). The runtime will then take care of passing that
message to the app via `update`.

### A giant leep for mankind

So what can we say. Well `stepperBuilder` could be named
`createOnUpdateHandler` and creates a function `onUpdateHandler` that will be
called by the runtime every time the model updates. `onUpdateHandler` takes
care of all the changes to the DOM needed to display your webapp. Tidy.

### Notes

#### 1

Elm curries functions. The js definition of `stepperBuilder` is a function that takes two arguments so this curried version isn't truely the type signature of `stepperBuilder`. We cannot write the true type signature in elm.

[stepper-worker]: https://github.com/elm/core/blob/22eefd207e7a63daab215ae497f683ff2319c2ca/src/Elm/Kernel/Platform.js#L26
[init-builder]: https://github.com/elm/core/blob/22eefd207e7a63daab215ae497f683ff2319c2ca/src/Elm/Kernel/Platform.js#L42
[init-stepper]: https://github.com/elm/core/blob/22eefd207e7a63daab215ae497f683ff2319c2ca/src/Elm/Kernel/Platform.js#L48
[stepper-element]:https://github.com/elm/browser/blob/1d28cd625b3ce07be6dfad51660bea6de2c905f2/src/Elm/Kernel/Browser.js#L37-L54

## 2020/5/4 -- Subscription mental models

I have consistantly found subscriptions to be the most confusing thing about
elm. The best way to grok them is just to use them and not think too much. I
think the cannonical explanations of commands live in the [effects/time] and
the [interop/ports] sections of the elm guide. Both of these sections are very
useful for helping folk understand how to effectively _use_ a subscription but
give nothing away about what a subscription really is.

Here is my take (and I guess, as of today, another-elm's take) as to what a
subscription is. Here is the mental model in three steps:

1. Events happen in the world, the elm app cannot control events, cause events
   or prevent events from happening. They just happen.
2. The elm runtime detects all events always: nothing happens that the runtime
   does not know about.
3. The runtime uses the `subscription: model -> Sub msg` function given to it
   on application init to filter events. If one of subscriptions currently
   active matches an event detected, the elm runtime will use that subscription
   to process the event and send it to the app (via the `update: msg -> model
   -> (model, Cmd msg)` function).

   (A subscriptions returned by `subscription: model -> Sub msg` is active
   between the time that the function returns and the next invocation of the
   function.)

To take the example of the `Time.every` function:

1. A event occurs repeatedly at a very small time period, say one millisecond.
2. The elm runtime detects all these notifications.
3. The runtime checks for a `Time.every` subscription, **if** it has one
   **and** the current time (measured relative to some epoch) is exactly a
   multiple of the time interval associated with the subscription **then** the
   runtime uses the tagger associated with the subscription to send a message
   to the app.

There are three issues with the mental model applied to the `Time.every`
function:

1. **It would require a huge amount of overhead in the runtime.** We can write
   clever kernel code that matches the mental model without actually
   implementing it.
2. **Elm uses floating point interval durations** which makes talk of 'exact
   multiples of intervals' invalid. I think using floating point interval
   durations is wrong. Time calculations should be exact. Therefore, I say we
   can ignore this issue for now.
3. **This mental model does not match behaviour of offical elm/time!** Oh well,
   at least it matches another-elm implementation.

On my todo list is to write a proposal to better specify the behaviour of
`Time.every` and to remove all the floating point badness from the module. Not
very high up my todo list though, partly because no one ever pays any attention
to such proposals.

Anyway, I have been rambling a bit, time(?) to bring this back on track and to
conclude. Subscriptions are hard to understand and this is not helped by the
lack of an officially blessed mental module. Implementing subscriptions in the
elm runtime is impossible with some mental module to base the implementation
on. Until such time as I find a better mental model, I will use this model for
subscriptions in another-elm.

[effects/time]: https://guide.elm-lang.org/effects/time.html#subscriptions
[/interop/ports]: https://guide.elm-lang.org/interop/ports.html#incoming-messages-sub

## 2020/5/2 -- Another elm

Here goes, a proper home for my take on the elm/* libraries. The idea is one
repository (<https://github.com/another-elm/std)> containing everything you
need (except the compiler) to use my custom implementation of the core
libraries.

The big new useful thing is a script './tools/another-elm' that can be used as
a drop in replacement for the elm compiler. It is (currently) pretty janky, be
prepared to regularly run `rm $ELM_HOME/another -r` when the compiler gets its
thread blocked indefinitely in MVar operators. That the elm compiler is
insanely fast means that running the elm compiler two or three times extra each
time is very doable. Try it out:

   sudo mkdir -p /opt/elm/
   sudo chown $USER /opt/elm
   git clone <https://github.com/another-elm/std> /opt/elm/std
   sudo ln -s /opt/elm/std/tools/another-elm /usr/local/bin/another-elm

## 2020/4/26 -- Merge elm/random back into core

In my book, things that can manage effects belong in elm/core. This merge
required replacing effect manager code with an alternative (in this case
channel based) implementation.

The new implementation is not that nice. Maybe it will look better when I
manage to unifiy the two Task types. I think this is a case where the effect
manager abstraction really worked well. I might just have my rose tinted
specticles on.

## 2020/4/26 -- A new internal module `Platform.Raw.Impure`

This module contains an abstaction for functions that **do things** when
they are run. The functions in this module are constrained to take one argument
and return the unit tuple.

Why can we not use Task's for this, given that this is _exactly_ what they are
intended for. Well, two reasons

1. Sometimes we need a guarantee that the function will be run exactly when we
   need to run. Task are always enqueued; they are only run after stepping
   through all the previous Tasks in the queue. Sometimes, this is not
   acceptable, for instance when updating the listeners for a subscription
   effect.

2. We need to use impure functions to run Tasks. The
   `Platform.Raw.Scheduler.enqueue` function takes a Task, adds it to the
   scheduler queue and, if the scheduler is not currently stepping tasks (i.e.
   this is not a reentrant call to `Platform.Raw.Scheduler.enqueue`), starts
   stepping. This function is impure. However, if we represented it as a Task
   we would have an infinite loop!

Hopefully, use of this module can be reduced to a couple of key places and
maybe even inlined into the scheduler is that is the only place that uses it.
Hopefully, it will help us move all effectful functions out of elm.

## 2020/04/26 - the future (?)

I wan't to move to away from callbacks and towards async/await and promises (or
futures). Firstly, I find that async/await is much easier to reason about than
callbacks and leads to much prettier code. Also, in the back of my mind is the
desire to eventually port the core libraries to rust for native compiled elm
code.

Todays change is just cosmetic, but hopefully is step 1.
