#! /usr/bin/env bash

set -o errexit;
set -o nounset;

if [[ ! -v ELM_HOME ]]; then
    printf "Please set ELM_HOME!"
    exit 1
fi

printf "Sucess if ends with DONE: "

ELM="${ELM:-elm}"
ELM_VERSION="$($ELM --version)"
CORE_GIT_DIR=$(realpath .)

echo CORE_GIT_DIR $CORE_GIT_DIR

rm -rf "$ELM_HOME/$ELM_VERSION/packages/elm/core/"

cd $1

if [[ ! -d elm-minimal-master ]]; then
    git clone https://github.com/harrysarson/elm-minimal > /dev/null
fi

cd elm-minimal-master
rm -rf elm-stuff
echo $(pwd)
$ELM make src/Main.elm --output /dev/null > /dev/null || true;


CORE_VERSION="$(ls $ELM_HOME/$ELM_VERSION/packages/elm/core/)"
CORE_PACKAGE_DIR="$ELM_HOME/$ELM_VERSION/packages/elm/core/$CORE_VERSION"
rm -rf "$CORE_PACKAGE_DIR" > /dev/null
ln -sv "$CORE_GIT_DIR" "$CORE_PACKAGE_DIR" > /dev/null

./refresh.sh "$CORE_GIT_DIR"

printf "DONE\n"

