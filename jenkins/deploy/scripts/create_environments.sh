#!/usr/bin/env bash
set -euo pipefail

if [ "x$1" = "xyes" ]; then
    boostrap=1
else
    boostrap=0
fi


set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(senv --input ${STACK_RELEASE}.yaml spack-checkout-dir)

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="echo senv"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="senv"
fi

environments=$(senv --input ${STACK_RELEASE}.yaml list-envs $2)

# Generate the list of software that need to be installed, then fetch every tarball
for environment in ${environments}
do
    if [ ! -e ${SPACK_CHECKOUT_DIR}/var/spack/environments/${environment}/spack.yaml ]; then
        ${SPACK_CHECKOUT_DIR}/bin/spack env create ${environment}
    fi

    echo "#### Create environment"
    senv --input ${STACK_RELEASE}.yaml \
        create-env \
        --env $environment

    cat -n ${SPACK_CHECKOUT_DIR}/var/spack/environments/${environment}/spack.yaml
done

# to reconfigure the compilers.yaml
${SENV} --input ${STACK_RELEASE}.yaml install-spack-default-configuration

if [ $boostrap -eq 0 ]; then
    echo "#### Install intel compilers configuration"
    # this has to be changed once we have a stack similar on all machines otherwhy
    # the config file will be rewriten for each environment
    ${SENV} --input ${STACK_RELEASE}.yaml intel-compilers-configuration
fi
