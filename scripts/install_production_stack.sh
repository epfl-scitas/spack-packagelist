#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

# Clean the workspace
rm -f stack.${SPACK_TARGET_TYPE}.xml

# Produce a valid list of compilers
. ${SENV_VIRTUALENV_PATH}/bin/activate
senv stack ${SPACK_TARGET_TYPE} --output stack.${SPACK_TARGET_TYPE}.txt
cat stack.${SPACK_TARGET_TYPE}.txt
deactivate

# Source Spack and add the system compiler
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
spack --version

# Register Spack bootstrapped compilers
TO_BE_INSTALLED=$(spack filter --not-installed $(cat stack.${SPACK_TARGET_TYPE}.txt))

if [[ -n "$TO_BE_INSTALLED" ]]
then
    spack spec -Il ${TO_BE_INSTALLED}
    spack install --log-format=junit --log-file=stack.${SPACK_TARGET_TYPE}.xml ${TO_BE_INSTALLED}
else
    echo $"[${SPACK_TARGET_TYPE} Stack already installed]"
    touch stack.${SPACK_TARGET_TYPE}.xml
fi
