#!/usr/bin/env bash
set -euo pipefail

environment=$(echo $NODE_LABELS | cut -d '-' -f 1)
echo "Environment $environment"

set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(senv --input ${STACK_RELEASE}.yaml spack-checkout-dir)
if [ x'${DRY_RUN}' = 'xyes' ]; then
    SENV="echo jenkins/senv.sh"
else
    SENV="jenkins/senv.sh"
fi

jenkins/senv.sh list-spec-to-activate \
    --env ${environment} > list_${environment}_activate.txt

echo "Activating packages"
${SENV} activate-specs \
    --env ${environment}

deactivate
