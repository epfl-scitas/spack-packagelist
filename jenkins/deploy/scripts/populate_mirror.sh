#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
# STACK_RELEASE: version of the stack
#
environments=$(senv --intput ${STACK_RELEASE}.yaml --list-envs)
if [ x'${DRY_RUN}' != 'x' ]; then
    SPACK='echo ${SPACK_CHECKOUT_DIR}/bin/spack'
    SENV='echo senv'
else
    SPACK='${SPACK_CHECKOUT_DIR}/bin/spack'
    SENV='senv'
fi

 . ${SENV_VIRTUALENV_PATH}/bin/activate

GET_ENTRY=senv --intput ${STACK_RELEASE}.yaml get-environment-entry

SPACK_MIRROR_DIR=$(${GET_ENTRY} spack_root)/$(${GET_ENTRY} mirrors.local)
environments=$(senv --intput ${STACK_RELEASE}.yaml --list-envs)

deactivate

spack --version
# Generate the list of software that need to be installed, then fetch every tarball
for environment in ${environments}
do
    ${SPACK} --env ${environment} mirror create -D -d ${SPACK_MIRROR_DIR} -a
done
