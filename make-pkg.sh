#! /bin/bash

set -u

## Make a simple elm app

# Why do this? If we run `elm make` in the elm/json package with an empty
# $ELM_HOME we get strange compiler ICE (that does not go away until we delete
# $ELM_HOME). This probably happens because elm/json has a circular dependancy
# on itself via elm/core which must confuse the compiler.
(
    cd "$(git rev-parse --show-toplevel)/tests/sscce-tests/suite/hello-world"
    another-elm make Main.elm --output /dev/null 1>/dev/null 2>/dev/null || true
)

## Make package

random_suffix=$(another-elm -Z --print-random-suffix)
sed_in_elm_files="find ./ -type f -name "*.elm" -exec sed -i -e"

$sed_in_elm_files "s/^import Elm\.Kernel\./-- UNDO import Elm.Kernel./g" {} \;
$sed_in_elm_files "s/Platform\.Unstable\./Platform.Unstable${random_suffix}./g" {} \;

another-elm make
code=$?

$sed_in_elm_files "s/-- UNDO import Elm\.Kernel\./import Elm.Kernel./g" {} \;
$sed_in_elm_files "s/Platform\.Unstable${random_suffix}\./Platform.Unstable./g" {} \;

exit $code
