#!/usr/bin/env bash
set -eo pipefail
. ${SENV_VIRTUALENV_PATH}/bin/activate

set -u
senv --input ${STACK_RELEASE}.yaml $@
