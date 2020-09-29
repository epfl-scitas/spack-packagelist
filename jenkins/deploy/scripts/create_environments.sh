#!/usr/bin/env bash
set -euo pipefail

if [ "x$1" = "x" ]; then
    boostrap=1
else
    boostrap=0
fi

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

if [ ! $boostrap ]; then
    # to reconfigure the compilers.yaml
    ${SENV} --input ${STACK_RELEASE}.yaml install-spack-default-configuration
    # this has to be changed once we have a stack similar on all machines otherwhy the config file will be rewriten for each environment
    ${SENV} --input ${STACK_RELEASE}.yaml intel-compilers-configuration
fi