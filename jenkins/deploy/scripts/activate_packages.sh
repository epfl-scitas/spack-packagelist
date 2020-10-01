#!/usr/bin/env bash
set -euo pipefail


set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(senv --input ${STACK_RELEASE}.yaml spack-checkout-dir)
if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
fi

senv --input ${STACK_RELEASE}.yaml \
    list-spec-to-activate \
    --env ${environment} > list_${environment}_activate.txt

echo "Activating packages"
cat list_${environment}_activate.txt  | xargs -L1 ${SPACK} --env ${environment} activate

deactivate
