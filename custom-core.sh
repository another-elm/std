#! /usr/bin/env bash

set -o errexit;
set -o nounset;

if [[ ! -v ELM_HOME ]]; then
    eprintf "Please set ELM_HOME!"
    exit 1
fi

printf "Sucess if ends with DONE: "

ELM="${ELM:-elm}"
ELM_VERSION="$($ELM --version)"
IFS=- read ELM_VERSION_START IGNORE <<< "$ELM_VERSION"

rm -rf "$ELM_HOME/$ELM_VERSION/packages/elm/core/"

if [[ ! -d elm-minimal-master ]]; then
    curl -sL https://github.com/harrysarson/elm-minimal/archive/master.tar.gz | tar xz
fi

cd elm-minimal-master
rm -rf elm-stuff
$ELM make src/Main.elm --output /dev/null > /dev/null || true;
cd - > /dev/null


CORE_VERSION="$(ls $ELM_HOME/$ELM_VERSION/packages/elm/core/)"
CORE_PACKAGE_DIR="$ELM_HOME/$ELM_VERSION/packages/elm/core/$CORE_VERSION"
CORE_GIT_DIR=$(realpath $1)

rm -rf "$CORE_PACKAGE_DIR" > /dev/null
ln -sv "$CORE_GIT_DIR" "$CORE_PACKAGE_DIR" > /dev/null
rm -vf "${CORE_GIT_DIR}"/*.dat "${CORE_GIT_DIR}"/doc*.json > /dev/null

printf "DONE\n"

