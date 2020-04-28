#!/usr/bin/env bash

set -o errexit;
set -o nounset;

#let the caller supply an ELM_TEST binary if desired
if [ -z "${ELM_TEST:-}" ]; then
    ELM_TEST=elm-test;
fi

DIR="$(dirname $0)";

cd "$DIR";

export ELM_HOME="$(pwd)/.elm";

../custom-core.sh ..

"${ELM_TEST}" "$@";
