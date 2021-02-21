#!/bin/bash

set -e

SYSCONFCPUS="$HOME/sysconfcpus"
ELM_MAKE="$HOME/$CIRCLE_PROJECT_REPONAME/node_modules/.bin/elm-make"

# Check if we have already patched it
if [ -f "${ELM_MAKE}-old" ];
then
    echo "Skipping ci-elm-hack"
    exit 0
fi

# Workaround for extremely slow elm compilation
# see https://github.com/elm-lang/elm-compiler/issues/1473#issuecomment-245704142
if [ ! -d "$SYSCONFCPUS/bin" ];
then
    git clone https://github.com/obmarg/libsysconfcpus.git "$SYSCONFCPUS"
    pushd "$SYSCONFCPUS"
    ./configure --prefix="$SYSCONFCPUS"
    make && make install
    popd
fi

mv "$ELM_MAKE" "$ELM_MAKE-old"
printf '%s\n\n' \
       '#!/bin/bash' \
       'echo "Running elm-make with sysconfcpus -n 2"' \
       "$SYSCONFCPUS"'/bin/sysconfcpus -n 2 '"$ELM_MAKE"'-old "$@"' \
       > "$ELM_MAKE"
chmod +x "$ELM_MAKE"
