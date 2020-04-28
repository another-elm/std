# Operators in elm

Elm programs use operators to consisely write some of the most common code.
For instance, elm provides arithmetic operators; it is far more consise to write `x * 5 + 1` than its equivilent written using functions (e.g. `add (multiply x 5) 1`).

Starting with the 0.19 release series only "core"¹ modules can define operators, effectively fixing the number of operators in the language.
The operators used by elm are [listed below](#listing).

## <a name="#defining-operators">Defining operators</a>

In elm, operators are defined in terms of a function.
For example in `elm/core` the `Basics` module defines the addition operator `+`

```elm

infix left  6 (+)  = add
--  ^  ^    ^  ^      ^
--  |  |     | |      |
-- (1) |    (3)|     (5)
--    (2)     (4)

add : number -> number -> number
add =
  Elm.Kernel.Basics.add

```

where `Elm.Kernel.Basics.add` is defined in JavaScript

```js
var _Basics_add = F2(function(a, b) { return a + b; });
```

The operator definition contains

1. The `infix` keyword enables the compiler to parse this line as an operator definition.
2. Associativity, in this case `left` meaning the compiler parses `4 + 5 + 7` as `(4 + 5) + 7`.
3. The precedence controlls what happens when different operators are used together.
    For example, `(+)` has precedence 6 and `(*)` has precedence 7 so the compiler parses `4 + 5 * 7` as `4 + (5 * 7)`.
4. The operator name enclosed in parentheses.
5. The function that the operator will bind to.
    Operators provide a simpler syntax for calling a function; the elm code `a + b` is equivilent to the code `Basics.add a b` (except the function `add` is not exposed by the `Basics` module).

## Compiling operators

All examples in this section are found within [OperatorExample.elm](./OperatorExample.elm) using `elm/core` version `1.0.2` and the offical elm compiler version `0.19.1`.

These are the elm functions we will use

```elm
compositionExample : (Float -> Float -> Float)
compositionExample x =
    mean 6
        >> mean x

mean : Float -> Float -> Float
mean a b =
    (a + b) / 2


ident : Bool -> Bool
ident b =
    not (not b)
```

### Operators: shorthand for functions

The operator `>>` composes functions together, for example `mean 6 >> mean x` is equilent to `\dummy => mean x (mean 6 dummy)`.
Compiling `compositionExample` generates the folling JavaScript:

```js
var $author$project$OperatorExample$compositionExample = function (x) {
    return A2(
        $elm$core$Basics$composeR,
        $author$project$OperatorExample$mean(6),
        $author$project$OperatorExample$mean(x));
};

```

It is clear that the compiler treats `mean 6 >> mean 21` as the function call `Basics.composeR (mean 6) mean(21)`; the operator has been substituted for a call to the function from which the operator is defined.

### Operaters: a suprising result

However, when we look at the JavaScript generated for `mean` we see something quite different:

```js
var $author$project$OperatorExample$mean = F2(
    function (a, b) {
        return (a + b) / 2;
    });

```

The compiler does not generate a call to `Basics.add` for the operator `+`, nor has does it generate a call to `Basics.fdiv` for the operator `/`!
Does this mean that using operators is not equivalent to calling the function from which it is defined?
No, it does not.
To see why take a look at the generated javascript for a third example `ident`.
`ident` takes a boolean value and inverts it twice so that it will always return the value it is given.

```js
var $author$project$OperatorExample$ident = function (b) {
    return !(!b);
};
```

As with `mean`, the compiler has refused to generate a call to `Basics.not` and instead uses the javascript `!` operator.
To understand this we need to dip our toes into the source code of the compiler itself.

### Special cases

In the section titled [Defining operators](#defining-operators) I claimed that "the elm code `a + b` is equivilent to the code `Basics.add a b`".
How can this be true if the compiler generated JavaScript for our example `mean` function does not contain a call to `$elm$core$Basics.add$`?
Surely the elm compiler must special case the addition operator?

No!
The elm compiler does not special case the addition operator; it special-cases `Basics.add`!
It also special-cases `Basics.not` expaining the generated JavaScript for our function `ident`.
Let us look at the Haskell code that makes these cases special:

#### [`generateCall`](https://github.com/elm/compiler/blob/0.19.1/compiler/src/Generate/JavaScript/Expression.hs#L386)

This haskell function generates JavaScript for every elm function call, we can see that it usually uses `generateCallHelp` to generate JavaScript.
However, when calling a function in the `elm/core` package the function instead calls `generateCoreCall`.

```hs
generateCall :: Mode.Mode -> Opt.Expr -> [Opt.Expr] -> JS.Expr
generateCall mode func args =
  case func of
    Opt.VarGlobal global@(Opt.Global (ModuleName.Canonical pkg _) _) | pkg == Pkg.core ->
      generateCoreCall mode global args

    -- snip

    _ ->
      generateCallHelp mode func args
```

#### [`generateCoreCall`](https://github.com/elm/compiler/blob/0.19.1/compiler/src/Generate/JavaScript/Expression.hs#L442)

`generateCoreCall` detects calls to function in the `Basics` module (and a couple of other modules not shown here) and calls `generateBasicsCall`.
Like `generateCall`, uses `generateCallHelp` to handle any calls to functions defined in modules the compile does not have a special case for.

```hs
generateCoreCall :: Mode.Mode -> Opt.Global -> [Opt.Expr] -> JS.Expr
generateCoreCall mode (Opt.Global home@(ModuleName.Canonical _ moduleName) name) args =
  if moduleName == Name.basics then
    generateBasicsCall mode home name args

  -- snip

  else
    generateGlobalCall home name (map (generateJsExpr mode) args)
```

#### [src/Generate/JavaScript/Expression.hs](https://github.com/elm/compiler/blob/0.19.1/compiler/src/Generate/JavaScript/Expression.hs#L503)

```hs
generateBasicsCall :: Mode.Mode -> ModuleName.Canonical -> Name.Name -> [Opt.Expr] -> JS.Expr
generateBasicsCall mode home name args =
  case args of
    [elmArg] ->
      let arg = generateJsExpr mode elmArg in
      case name of
        "not"      -> JS.Prefix JS.PrefixNot arg
        -- snip
        _          -> generateGlobalCall home name [arg]

    [elmLeft, elmRight] ->
      case name of
        -- snip
        _ ->
          let
            left = generateJsExpr mode elmLeft
            right = generateJsExpr mode elmRight
          in
          case name of
            "add"  -> JS.Infix JS.OpAdd left right

            -- snip

            _      -> generateGlobalCall home name [left, right]

    _ ->
      generateGlobalCall home name (map (generateJsExpr mode) args)
```

## <a name="#listing">Elm operator listing </a>

<style type = "text/css">
table.wikitable, tr, td, th {
    border: 1px solid black;
    border-collapse: collapse;
    padding: 0.5em;
}
</style>

<table class="wikitable">
    <tbody>
        <tr>
            <th>Precedence</th>
            <th>Syntax</th>
            <th>Description</th>
            <th>Source</th>
            <th>Associativity</th>
        </tr>
        <tr>
            <th rowspan="2">9
                <p><small>highest</small></p>
            </th>
            <td><code>f << g</code></td>
            <td>Functional composition</td>
            <td><code>elm/core:Basics</code></td>
            <td>conflicting</td>
        </tr>
        <tr>
            <td><code>g >> f</code></td>
            <td>Functional composition</td>
            <td><code>elm/core:Basics</code></td>
            <td>conflicting</td>
        </tr>
        <tr>
            <th>8</th>
            <td><code>a ^ b</code></td>
            <td>Exponentation</td>
            <td><code>elm/core:Basics</code></td>
            <td>right-to-left</td>
        </tr>
        <tr>
            <th rowspan="3">7</th>
            <td><code>a * b</code></td>
            <td>Multiplication</td>
            <td><code>elm/core:Basics</code></td>
            <td rowspan="3">left-to-right</td>
        </tr>
        <tr>
            <td><code>a / b</code></td>
            <td>Floating-point division</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
        <tr>
            <td><code>a // b</code></td>
            <td>Integer division</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
        <tr>
            <th rowspan="2">6</th>
            <td><code>a + b</code></td>
            <td>Addition</td>
            <td><code>elm/core:Basics</code></td>
            <td rowspan="2">left-to-right</td>
        </tr>
        <tr>
            <td><code>a - b</code></td>
            <td>Subtraction</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
        <tr>
            <th rowspan="2">5</th>
            <td><code>xs ++ ys</code></td>
            <td>Append</td>
            <td><code>elm/core:Basics</code></td>
            <td rowspan="2">right-to-left</td>
        </tr>
        <tr>
            <td><code>a :: xs</code></td>
            <td>List construction</td>
            <td><code>elm/core:List</code></td>
        </tr>
        <tr>
            <th rowspan="6">4</th>
            <td><code>a == b</code></td>
            <td>Equality</td>
            <td><code>elm/core:Basics</code></td>
            <td rowspan="6">conflicting</td>
        </tr>
        <tr>
            <td><code>a /= b</code></td>
            <td>Inequality</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
        <tr>
            <td><code>a < b</code></td>
            <td>Less than</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
        <tr>
            <td><code>a > b</code></td>
            <td>Greater than</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
        <tr>
            <td><code>a <= b</code></td>
            <td>Less than equal to</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
        <tr>
            <td><code>a >= b</code></td>
            <td>Greater than equal to</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
        <tr>
            <th>3</th>
            <td><code>a && b</code></td>
            <td>Logical AND</td>
            <td><code>elm/core:Basics</code></td>
            <td>right-to-left</td>
        </tr>
        <tr>
            <th>2</th>
            <td><code>a || b</code></td>
            <td>Logical OR</td>
            <td><code>elm/core:Basics</code></td>
            <td>right-to-left</td>
        </tr>
        <tr>
            <th rowspan="2">0
                <p><small>lowest</small></p>
            </th>
            <td><code>a |> b</code></td>
            <td>Pipe operator</td>
            <td><code>elm/core:Basics</code></td>
            <td rowspan="2">conflicts</td>
        </tr>
        <tr>
            <td><code>a <| b</code></td>
            <td>Pipe operator</td>
            <td><code>elm/core:Basics</code></td>
        </tr>
    </tbody>
</table>

---

### Notes

1. "Core" modules describe all modules in the elm and elm-exploration organisations.
