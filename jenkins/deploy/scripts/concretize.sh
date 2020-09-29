#!/usr/bin/env bash
set -euo pipefail

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
fi

${SPACK} --env ${environment} concretize
