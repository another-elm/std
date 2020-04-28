# Elm-in-elm core libraries

> This repository currently contains a work in progress attempt to rewrite the elm core libraries into a form better suited for elm-in-elm.
> It has not yet been upstreamed or adopted by elm-in-elm; I hope one day to integrate this into elm-in-elm but currently is just my work.

## Aims

* Minimal amount of Kernel code.
* Easy to read.

## Rules

* Each kernel function may only be called via a type annotated redefinition in an elm file.
* Kernel functions may **not** call other kernel functions.
