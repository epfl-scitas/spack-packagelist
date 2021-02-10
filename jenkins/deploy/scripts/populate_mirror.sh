#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
# STACK_RELEASE: version of the stack
#

set +u
if [ "x$1" != "x" ]; then
    filter=$1
else
    filter=""
fi

. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(senv --input ${STACK_RELEASE}.yaml spack-checkout-dir)


if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV='echo jenkins/senv.sh'
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV='jenkins/senv.sh'
fi

GET_ENTRY="jenkins/senv.sh get-environment-entry"

in_pr=$(${GET_ENTRY} in_pr | head -n1)
if [ "${in_pr}" = "true" ]; then
    SPACK_MIRROR_DIR=$(${GET_ENTRY} mirrors.pr_local)
else
    SPACK_MIRROR_DIR=$(${GET_ENTRY} spack_root)/$(${GET_ENTRY} mirrors.local)
fi
environments=$(jenkins/senv.sh  list-envs $filter)

deactivate

# Generate the list of software that need to be installed, then fetch every tarball
set +e
for environment in ${environments}
do
    ${SPACK} --env ${environment} mirror create -D -d ${SPACK_MIRROR_DIR} -a
done

true
