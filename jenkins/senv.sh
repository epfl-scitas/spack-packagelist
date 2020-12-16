#!/usr/bin/env bash
set -eo pipefail
. ${SENV_VIRTUALENV_PATH}/bin/activate

prefix_=""
if [ "$STACK_PREFIX" != "" ]
then
    prefix_="--prefix=${STACK_PREFIX}"
fi

set -u
senv --input ${STACK_RELEASE}.yaml ${prefix_} $@
