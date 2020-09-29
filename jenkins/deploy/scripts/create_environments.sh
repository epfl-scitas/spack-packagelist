#!/usr/bin/env bash
set -euo pipefail

set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

environments=$(senv --input ${STACK_RELEASE}.yaml list-envs)

# Generate the list of software that need to be installed, then fetch every tarball
for environment in ${environments}
do
    if [ ! -e ${SPACK_CHECKOUT_DIR}/var/spack/environments/${environment}/spack.yaml ]; then
        ${SPACK_CHECKOUT_DIR}/bin/spack env create ${environment}
    fi

    senv --input ${STACK_RELEASE}.yaml \
        create-env \
        --env $environment
done
