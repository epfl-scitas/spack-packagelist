#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

environment=$1

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="echo senv"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="senv"
fi

# Clean old test results from the workspace
set +e
mv -f compilers.${environment}.xml old_compilers.${environment}.xml
set -e

# Produce a valid list of compilers
set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

mkdir -p ${SPACK_CHECKOUT_DIR}/etc/spack/licenses/intel
cp external/intel/licenses/scitas_license.lic \
    ${SPACK_CHECKOUT_DIR}/etc/spack/licenses/intel/license.lic

senv --input ${STACK_RELEASE}.yaml \
    list-compilers \
    --env $environment > list_${environment}_compilers.txt
senv --input ${STACK_RELEASE}.yaml \
    list-compilers >> list_${environment}_compilers.txt

# Source Spack and add the system compiler
${SPACK} --version

compilers_to_install=$(cat list_${environment}_compilers.txt | sort -u)
${SPACK} --env ${environment} install -v --log-format=junit --log-file=compilers.${environment}.xml ${compilers_to_install}

senv --input ${STACK_RELEASE}.yaml list-compilers --env ${environment} --stack-type stable | xargs -L1 ${SPACK} module lmod setdefault
