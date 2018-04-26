#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to setup the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

SPACK_MIRROR_DIR=/ssoft/spack/mirror

# Activate 'senv' and source Spack setup file
. ${SENV_VIRTUALENV_PATH}/bin/activate
senv --help
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
spack --version

# Generate the list of software that need to be installed, then fetch every tarball
for target in $(senv targets)
do
    echo "[${target}] Updating mirror"
    senv packages ${target} --output="all_specs.${target}.txt"
    # TODO: if concretization is slow this command could output also the yaml file
    spack filter --not-installed $(cat all_specs.${target}.txt) > to_be_installed.${target}.txt
    spack spec -y $(cat to_be_installed.${target}.txt) > specs.${target}.yaml
    # TODO: read directly from a yaml file to avoid concretization slowdowns
    spack mirror create -D -d ${SPACK_MIRROR_DIR} -f to_be_installed.${target}.txt
done
