#! /usr/bin/env bash

set -o errexit;
set -o nounset;

ELM="${ELM:-elm}"
ELM_VERSION="$($ELM --version)"
CORE_GIT_DIR=$(realpath .)


rm -rf "$ELM_HOME"
cd $(mktemp -d)

git clone -q https://github.com/harrysarson/elm-minimal
cd elm-minimal
yes | $ELM install elm/time
yes | $ELM install elm/random
$ELM make src/Main.elm --output /dev/null || true

