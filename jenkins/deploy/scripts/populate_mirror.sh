#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
# STACK_RELEASE: version of the stack
#

SPACK_MIRROR_DIR=/ssoft/spack/mirror

# Activate 'senv' and source Spack setup file
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
spack --version

. ${SENV_VIRTUALENV_PATH}/bin/activate

environments=$(senv --intput ${STACK_RELEASE}.yaml --list-envs)

# Generate the list of software that need to be installed, then fetch every tarball
for environment in ${environments}
do
    spack env activate ${environment}
    spack mirror create -D -d ${SPACK_MIRROR_DIR} -a
    spack env deactivate
done
