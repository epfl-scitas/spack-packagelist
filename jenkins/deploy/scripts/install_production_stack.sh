#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

environment=$1

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK='echo ${SPACK_CHECKOUT_DIR}/bin/spack'
    SENV='echo senv'
else
    SPACK='${SPACK_CHECKOUT_DIR}/bin/spack'
    SENV='senv'
fi

# Clean the workspace
set +e
rm -f stack.${environment}.xml
set -e

# Register Spack bootstrapped compilers
${SPACK} --env ${environment} concretize
${SPACK} --env ${environment} install --log-format=junit --log-file=stack.${environment}.xml

# not really sure why modules are not created
${SPACK} --env ${environment} module lmod refresh -y
