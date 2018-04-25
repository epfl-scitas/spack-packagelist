#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

# Produce a valid list of compilers
. ${SENV_VIRTUALENV_PATH}/bin/activate
senv compilers ${SPACK_TARGET_TYPE} --output compilers.${SPACK_TARGET_TYPE}.txt
cat compilers.${SPACK_TARGET_TYPE}.txt
deactivate

# Source Spack and add the system compiler
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
spack --version
spack compiler add --scope=site

# Register Spack bootstrapped compilers
spack spec -Il $(cat compilers.${SPACK_TARGET_TYPE}.txt)
spack install --log-format=junit --log-file=compilers.${SPACK_TARGET_TYPE}.xml $(cat compilers.${SPACK_TARGET_TYPE}.txt)
while read -r line
do
    spack compiler add --scope=site --spec ${line}
done < compilers.${SPACK_TARGET_TYPE}.txt
