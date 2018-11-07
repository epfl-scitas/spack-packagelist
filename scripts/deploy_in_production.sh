#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

# Clean the workspace
rm -f spec.${SPACK_TARGET_TYPE}.xml

# Source Spack setup file
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
spack --version

# Install the software that is missing

specs_to_be_installed=$(cat to_be_installed.${SPACK_TARGET_TYPE}.txt)

if [[ -z "${specs_to_be_installed}" ]]
then
    echo "[${SPACK_TARGET_TYPE}] Nothing to install"
    cp resources/success.xml spec.${SPACK_TARGET_TYPE}.xml
else
    spack install --log-file=spec.${SPACK_TARGET_TYPE}.xml --log-format=junit ${specs_to_be_installed}
fi

# Activate python extensions

# Set the line separator to be only the newline character
#
# https://askubuntu.com/questions/344407/how-to-read-complete-line-in-for-loop-with-spaces
# https://unix.stackexchange.com/questions/16192/what-is-the-ifs
#
IFS=$'\n'
for spec in $(cat to_be_installed.${SPACK_TARGET_TYPE}.txt)
do
    # Activate python extensions
    if [[ "${spec}" =~ ^py- ]]
    then
        echo "[ACTIVATION] ${spec}"
        spack activate ${spec}
    fi
done
