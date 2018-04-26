#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

# Activate 'senv' and source Spack setup file
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
spack --version

# Install the software that is missing
spack install -f specs.${SPACK_TARGET_TYPE}.yaml --log-file=spec.${SPACK_TARGET_TYPE}.xml --log-format=junit
