
if [[ ! -v ELM_HOME ]] || [[ $ELM_HOME != */custom-core ]]; then
    export ELM_HOME="${ELM_HOME:-"$HOME/.elm"}/custom-core";
fi

bash <<"EOF"

set -o errexit;
set -o nounset;

printf "Sucess if ends with DONE: "

ELM="${ELM:-elm}"
ELM_VERSION="$($ELM --version)"
IFS=- read ELM_VERSION_START IGNORE <<< "$ELM_VERSION"

rm -rf elm-minimal-master
curl -sL https://github.com/harrysarson/elm-minimal/archive/master.tar.gz | tar xz
cd elm-minimal-master
$ELM make src/Main.elm --output /dev/null > /dev/null || true;
cd - > /dev/null
rm -rf elm-minimal-master


CORE_VERSION="$(ls $ELM_HOME/$ELM_VERSION/packages/elm/core/)"
CORE_PACKAGE_DIR="$ELM_HOME/$ELM_VERSION/packages/elm/core/$CORE_VERSION"
CORE_GIT_DIR=$(pwd)

rm -rf "$CORE_PACKAGE_DIR" > /dev/null
ln -sv "$CORE_GIT_DIR" "$CORE_PACKAGE_DIR" > /dev/null
rm -vf "${CORE_GIT_DIR}"/*.dat "${CORE_GIT_DIR}"/doc*.json > /dev/null

printf "DONE\n"

EOF
