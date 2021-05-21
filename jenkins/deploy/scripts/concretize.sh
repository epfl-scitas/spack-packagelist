#!/usr/bin/env bash
set -euo pipefail

environment=$(echo $NODE_LABELS | cut -d '-' -f 1)
echo "Environment $environment"

set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(jenkins/senv.sh --input ${STACK_RELEASE}.yaml spack-checkout-dir)

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
fi

${SPACK} --env ${environment} concretize
