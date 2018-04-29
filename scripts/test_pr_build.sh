#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SPACK_PRODUCTION_DIR: path where the production instance of Spack resides
#

# Retrieve which Spack instance we need to use for the build
SPACK_CHECKOUT_DIR=$(cat spack_dir.txt)

# Try to install the specs
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
# We need to install Intel to have the intel module available
# in the temporary workspace
spack install intel@18.0.2 %gcc@4.8.5
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
which spack
spack mirror list

specs_to_be_installed=$(cat to_be_installed.${SPACK_TARGET_TYPE}.txt)

if [[ -z "${specs_to_be_installed}" ]]
then
    echo "[${SPACK_TARGET_TYPE}] Nothing to install"
    cp resources/success.xml spec.${SPACK_TARGET_TYPE}.xml
else
    spack install --log-file=spec.${SPACK_TARGET_TYPE}.xml --log-format=junit ${specs_to_be_installed}
fi
