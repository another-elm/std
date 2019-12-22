#! /usr/bin/env bash

set -o errexit;
set -o nounset;

if [[ ! -v ELM_HOME ]]; then
    printf "Please set ELM_HOME!\n"
    exit 1
fi

printf "Sucess if ends with DONE: "

ELM="${ELM:-elm}"
ELM_VERSION="$($ELM --version)"

cd $1

CORE_VERSIONS_DIR="$ELM_HOME/$ELM_VERSION/packages/elm/core"

if [[ -d "$CORE_VERSIONS_DIR" ]]; then

    CORE_VERSION_COUNT=$(ls "$CORE_VERSIONS_DIR" | wc -l)
    CORE_VERSION=$(ls "$CORE_VERSIONS_DIR")
    CORE_PACKAGE_DIR="$CORE_VERSIONS_DIR/$CORE_VERSION"

    if [ CORE_VERSION_COUNT == 1 ] || [[ -f $CORE_PACKAGE_DIR/custom ]]; then
        printf "REFRESH "
    else
        printf "INIT "
        ./init-elm-home.sh > /dev/null
    fi
else
    printf "INIT "
    ./init-elm-home.sh > /dev/null
fi

CORE_VERSION=$(ls $CORE_VERSIONS_DIR)
CORE_PACKAGE_DIR="$CORE_VERSIONS_DIR/$CORE_VERSION"

rm -rf "$CORE_PACKAGE_DIR" > /dev/null
mkdir "$CORE_PACKAGE_DIR"
cp -r src "$CORE_PACKAGE_DIR"/ > /dev/null
cp -r elm.json "$CORE_PACKAGE_DIR"/ > /dev/null
touch "$CORE_PACKAGE_DIR/custom"

printf "DONE\n"
