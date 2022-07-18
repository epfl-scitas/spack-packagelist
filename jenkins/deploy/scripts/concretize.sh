#!/usr/bin/env bash
set -euo pipefail

environment=$(echo $NODE_LABELS | cut -d '-' -f 1)
echo "Environment $environment"

set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(jenkins/senv.sh spack-checkout-dir)

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
fi

echo "${SPACK} -d --env ${environment} concretize"
${SPACK} -d --env ${environment} concretize
