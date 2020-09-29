#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

environment=$1

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="echo senv"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="senv"
fi

# Clean the workspace
set +e
rm -f stack.${environment}.xml
set -e

${SPACK} --env ${environment} install -v --log-format=junit --log-file=stack.${environment}.xml

${SPACK} --env ${environment} module lmod refresh -y
