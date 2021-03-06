# Elm in the Browser!

This package allows you to create Elm programs that run in browsers.


## Learning Path

**I highly recommend working through [guide.elm-lang.org][guide] to learn how to use Elm.** It is built around a learning path that introduces concepts gradually.

[guide]: https://guide.elm-lang.org/

You can see the outline of that learning path in the `Browser` module. It lets you create Elm programs with the following functions:

  1. [`sandbox`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#sandbox) &mdash; react to user input, like buttons and checkboxes
  2. [`element`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#element) &mdash; talk to the outside world, like HTTP and JS interop
  3. [`document`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#document) &mdash; control the `<title>` and `<body>`
  4. [`application`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#application) &mdash; create single-page apps

This order works well because important concepts and techniques are introduced at each stage. If you jump ahead, it is like building a house by starting with the roof! So again, **work through [guide.elm-lang.org][guide] to see examples and really *understand* how Elm works!**

This order also works well because it mirrors how most people introduce Elm at work. Start small. Try using Elm in a single element in an existing JavaScript project. If that goes well, try doing a bit more. Etc.

## Work with URLs

This package helps you (1) build new URLs and (2) parse existing URLs into nice Elm data structures.

These tasks are quite common when building web apps in Elm with [`Browser.application`](https://package.elm-lang.org/packages/elm/browser/latest/Browser#application)!

### What is a URL

A URL is defined by Tim Berners-Lee in [this document](https://tools.ietf.org/html/rfc3986). It is worth reading, but I will try to share some highlights. He shares an example like this:

```
  https://example.com:8042/over/there?name=ferret#nose
  \___/   \______________/\_________/ \_________/ \__/
    |            |            |            |        |
  scheme     authority       path        query   fragment
```

And here are some facts that I found surprising:

- **ASCII** &mdash; The spec only talks about ASCII characters. Behavior with other encodings is unspecified, so if you use a UTF-8 character directly, it may be handled differently by browsers, packages, and servers! No one is wrong. It is just unspecified. So I would stick to ASCII to be safe.
- **Escaping** &mdash; There are some reserved characters in the spec, like `/`, `?`, and `#`. So what happens when you need those in your query? The spec allows you to “escape” characters (`/` => `%2F`, `?` => `%3F`, `#` => `%23`) so it is clearly not a reserved characters anymore. The spec calls this [percent-encoding](https://tools.ietf.org/html/rfc3986#section-2.1). The basic idea is to look up the hex code in [the ASCII table](https://ascii.cl/) and put a `%` in front. There are many subtleties though, so I recommend reading [this](https://en.wikipedia.org/wiki/Percent-encoding) for more details!

> **Note:** The difference between a URI and a URL is kind of subtle. [This post](https://danielmiessler.com/study/url-uri/) explains the difference nicely. I decided to call this library `elm/url` because it is primarily concerned with HTTP which does need actual locations.

### Related Work

The API in `Url.Parser` is quite distinctive. I first saw the general idea in Chris Done&rsquo;s [formatting][] library. Based on that, Noah and I outlined the API you see in `Url.Parser`. Noah then found Rudi Grinberg&rsquo;s [post][] about type safe routing in OCaml. It was exactly what we were going for. We had even used the names `s` and `(</>)` in our draft API! In the end, we ended up using the “final encoding” of the EDSL that had been left as an exercise for the reader. Very fun to work through!

[formatting]: https://chrisdone.com/posts/formatting
[post]: http://rgrinberg.com/posts/primitive-type-safe-routing/
