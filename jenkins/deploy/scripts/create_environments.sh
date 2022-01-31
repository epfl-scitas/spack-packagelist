#!/usr/bin/env bash
set -euo pipefail

if [ "x$1" = "xyes" ]; then
    boostrap=1
else
    boostrap=0
fi

set +u
if [ "x$2" != "x" ]; then
    filter=$2
else
    filter=""
fi

. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(jenkins/senv.sh spack-checkout-dir)

echo "SPACK_CHECKOUT_DIR=${SPACK_CHECKOUT_DIR}"

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="echo jenkins/senv.sh"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="jenkins/senv.sh"
fi

environments=$(jenkins/senv.sh list-envs $filter)

# Generate the list of software that need to be installed, then fetch every tarball
for environment in ${environments}
do
    echo "#### Create environment ${environment}"
    if [ ! -e ${SPACK_CHECKOUT_DIR}/var/spack/environments/${environment}/spack.yaml ]; then
        ${SPACK_CHECKOUT_DIR}/bin/spack env create ${environment}
    fi

    jenkins/senv.sh create-env --env $environment

    cat -n ${SPACK_CHECKOUT_DIR}/var/spack/environments/${environment}/spack.yaml
done

# to reconfigure the compilers.yaml
${SENV} install-spack-default-configuration

echo "Bootstrap $boostrap $filter"

if [[ $boostrap -eq 0 && ! "x$filter" =~ "cloud=\w*" ]]; then
    echo "#### Install intel compilers configuration"
    # this has to be changed once we have a stack similar on all machines otherwhy
    # the config file will be rewriten for each environment
    ${SENV} intel-compilers-configuration
fi
