#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
# STACK_RELEASE: version of the stack
#

if [ x'${DRY_RUN}' != 'x' ]; then
    SPACK='echo ${SPACK_CHECKOUT_DIR}/bin/spack'
    SENV='echo senv'
else
    SPACK='${SPACK_CHECKOUT_DIR}/bin/spack'
    SENV='senv'
fi

set +u
 . ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

GET_ENTRY="senv --input ${STACK_RELEASE}.yaml get-environment-entry"
SPACK_MIRROR_DIR=$(${GET_ENTRY} spack_root)/$(${GET_ENTRY} mirrors.local)
environments=$(senv --input ${STACK_RELEASE}.yaml list-envs)

deactivate

# Generate the list of software that need to be installed, then fetch every tarball
for environment in ${environments}
do
    ${SPACK} --env ${environment} mirror create -D -d ${SPACK_MIRROR_DIR} -a
done
