## Releases

| Version                                                                              | Notes                                                                                                                                                     |
| ------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [**1.2.2**](https://github.com/elm-explorations/test/tree/1.2.2)                     | Fixes a crash in `Test.Html` when the HTML contains nested `Html.Lazy` nodes. [#78](https://github.com/elm-explorations/test/issues/78)                   |
| [**1.2.1**](https://github.com/elm-explorations/test/tree/1.2.1)                     | Many small documentation fixes.  Improve error messages when failing to simulate an event.                                                                |
| [**1.2.0**](https://github.com/elm-explorations/test/tree/1.2.0)                     | Add HTML tests. [#41](https://github.com/elm-explorations/test/pull/41)
| [**1.0.0**](https://github.com/elm-explorations/test/tree/1.0.0)                     | Update for Elm 0.19. Remove `Fuzz.andThen`, `Fuzz.conditional`, and `Test.Runner.getFailure`. Fail on equating floats to encourage checks with tolerance. `Test.Runner.fuzz` now returns a `Result`. |
| renamed from **elm-community/elm-test** (below) to **elm-explorations/test** (above) |                                                                                                                                                           |
| [**4.0.0**](https://github.com/elm-community/elm-test/tree/4.0.0)                    | Add `only`, `skip`, `todo`; change `Fuzz.frequency` to fail rather than crash on bad input, disallow tests with blank or duplicate descriptions.          |
| [**3.1.0**](https://github.com/elm-community/elm-test/tree/3.1.0)                    | Add `Expect.all`                                                                                                                                          |
| [**3.0.0**](https://github.com/elm-community/elm-test/tree/3.0.0)                    | Update for Elm 0.18; switch the argument order of `Fuzz.andMap`.                                                                                          |
| [**2.1.0**](https://github.com/elm-community/elm-test/tree/2.1.0)                    | Switch to rose trees for `Fuzz.andThen`, other API additions.                                                                                             |
| [**2.0.0**](https://github.com/elm-community/elm-test/tree/2.0.0)                    | Scratch-rewrite to project-fuzzball                                                                                                                       |
| [**1.0.0**](https://github.com/elm-community/elm-test/tree/1.0.0)                    | ElmTest initial release                                                                                                                                   |