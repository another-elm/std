#! /bin/bash

set -eu

random_suffix=$(another-elm -Z --print-random-suffix)
sed_in_elm_files="find ./ -type f -name "*.elm" -exec sed -i -e"


$sed_in_elm_files "s/^import Elm\.Kernel\./-- UNDO import Elm.Kernel./g" {} \;
$sed_in_elm_files "s/Platform\.Unstable\./Platform.Unstable${random_suffix}./g" {} \;

another-elm make

$sed_in_elm_files "s/-- UNDO import Elm\.Kernel\./import Elm.Kernel./g" {} \;
$sed_in_elm_files "s/Platform\.Unstable${random_suffix}\./Platform.Unstable./g" {} \;

