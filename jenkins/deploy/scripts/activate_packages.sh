#!/usr/bin/env bash
set -euo pipefail

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
fi

# Produce a valid list of compilers
set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

senv --input ${STACK_RELEASE}.yaml \
    list-spec-to-activate \
    --env ${environment} > list_${environment}_activate.txt

cat list_${environment}_activate.txt  | xargs -L1 ${SPACK} --env ${environment} activate

deactivate
