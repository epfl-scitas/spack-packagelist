#!/usr/bin/env bash
set -eo pipefail
. ${SENV_VIRTUALENV_PATH}/bin/activate

prefix_=""
if [ "x${STACK_PREFIX}" != "x" ]
then
    prefix_="--prefix ${STACK_PREFIX}"
fi

if [ "x${SENV_OVERRIDE}" == "x" ]; then
    SENV_OVERRIDE='{}'
fi

set -u
echo "senv --input ${STACK_RELEASE}.yaml --override "${SENV_OVERRIDE}" ${prefix_} $@" 1>&2
senv --input ${STACK_RELEASE}.yaml --debug --override "${SENV_OVERRIDE}" ${prefix_} $@
