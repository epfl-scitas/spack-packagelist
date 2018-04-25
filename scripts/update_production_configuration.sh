#!/usr/bin/env bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

# Recreate the virtualenv and update the command line
mkdir -p ${SENV_VIRTUALENV_PATH}
virtualenv --version
virtualenv -p $(which python) ${SENV_VIRTUALENV_PATH} --clear
. ${SENV_VIRTUALENV_PATH}/bin/activate
pip install --force-reinstall -U .
senv --help

# Copy configuration files into the correct place
cp -v configuration/* ${SPACK_CHECKOUT_DIR}/etc/spack/
# FIXME: remove this comment when adding Intel back
# cp -v -r external/* /ssoft/spack/external/
