#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

# Recreate the virtualenv and update the command line
echo '(Re)installing senv'
mkdir -p ${SENV_VIRTUALENV_PATH}
virtualenv --version
virtualenv -p $(which python2.7) ${SENV_VIRTUALENV_PATH} --clear

set +u # bug fix for virtualenv <16.2
. ${SENV_VIRTUALENV_PATH}/bin/activate

pip install -U pip

pip install --force-reinstall -U .
