#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
#

environment=$(echo $NODE_LABELS | cut -d '-' -f 1)
echo "Environment $environment"

set +e
rm -f stack.${environment}.xml
set -e

set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(jenkins/senv.sh spack-checkout-dir)

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="echo jenkins/senv.sh"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="jenkins/senv.sh"
fi


${SPACK} --env ${environment} install --log-format=junit --log-file=stack.${environment}.xml

${SPACK} --env ${environment} module lmod refresh -y

if [ ${environment} = 'gacrux' ]; then
    _prefix=$(${SENV} get-environment-entry prefix)
    _stack_release=$(${SENV} get-environment-entry stack_release)
    _stack_version=$(${SENV} get-environment-entry stack_version)
    cd ${_prefix}/${_stack_release}/${_stack_version}/share/spack/lmod
    ln -sf gacrux helvetios
fi
