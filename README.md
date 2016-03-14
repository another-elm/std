# Virtual DOM for Elm

[![Build Status](https://travis-ci.org/elm-lang/virtual-dom.svg)](https://travis-ci.org/elm-lang/virtual-dom)

In the past, application developers needed to mess with the DOM by hand. This introduced a variety of possible pitfalls:

  * Touching the DOM can be extremely slow. For example, if you change the DOM and *then* try to read some information from it, you usually need to reflow everything to ensure that the data is "up to date". This makes it extremely easy for innocent-looking code to be extremely slow.

  * Touching the DOM is very error prone. By splitting your application’s state between the DOM and your program, you are more likely to lose track of what is going on and have bad emergent architecture.

 So **Virtual DOM** has you build up a representation of the DOM on each frame instead. With some pretty simple performance tricks, this ends up being quite a lot faster than naive hand-written code and lead to much better architecture overall.
