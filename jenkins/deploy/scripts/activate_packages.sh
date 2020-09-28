#!/usr/bin/env bash
set -euo pipefail

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK='echo spack'
else
    SPACK='spack'
fi

# Produce a valid list of compilers
set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

senv --input ${STACK_RELEASE}.yaml list-spec-to-activate --env ${environment}  | xargs -L1 ${SPACK} activate

deactivate
