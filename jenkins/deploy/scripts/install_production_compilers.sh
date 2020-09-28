#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

environment=$1

if [ x'${DRY_RUN}' != 'x' ]; then
    SPACK='echo ${SPACK_CHECKOUT_DIR}/bin/spack'
    SENV='echo senv'
else
    SPACK='${SPACK_CHECKOUT_DIR}/bin/spack'
    SENV='senv'
fi

# Clean old test results from the workspace
set +e
mv -f compilers.${environment}.xml old_compilers.${environment}.xml
set -e

# Produce a valid list of compilers
set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

senv --input ${STACK_RELEASE}.yaml \
    list-compilers \
    --env $environment > list_${environment}_compilers.txt
senv --input ${STACK_RELEASE}.yaml \
    list-compilers >> list_${environment}_compilers.txt

if [ ! -e ${SPACK_CHECKOUT_DIR}/var/spack/environments/${environment}/spack.yaml ]; then
    ${SPACK_CHECKOUT_DIR}/bin/spack env create ${environment}
fi

senv --input ${STACK_RELEASE}.yaml \
    create-env \
    --env $environment

# Source Spack and add the system compiler
${SPACK} --version

compilers_to_install=$(cat list_${environment}_compilers.txt | sort -u)
${SPACK} --env ${environment} install --log-format=junit --log-file=compilers.${environment}.xml ${compilers_to_install}

senv --input ${STACK_RELEASE}.yaml list-compilers --env ${environment} --stack-type stable | xargs -L1 ${SPACK} module lmod setdefault

# to reconfigure the compilers.yaml
${SENV} --input ${STACK_RELEASE}.yaml install-spack-default-configuration

# this has to be changed once we have a stack similar on all machines otherwhy the config file will be rewriten for each environment
${SENV} --input ${STACK_RELEASE}.yaml intel-compilers-configuration
