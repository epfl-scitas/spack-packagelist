#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

environment=$1

# Clean the workspace
rm -f stack.${environment}.xml

# Produce a valid list of compilers
. ${SENV_VIRTUALENV_PATH}/bin/activate
senv --input ${STACK_RELEASE}.yaml create-env --env ${env}
deactivate

# Source Spack and add the system compiler
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
spack --version

spack env activate ${environment}

# Register Spack bootstrapped compilers
spack concretize --force
spack install --log-format=junit --log-file=stack.${environment}.xml

# not really sure why modules are not created
spack module lmod refresh -y
