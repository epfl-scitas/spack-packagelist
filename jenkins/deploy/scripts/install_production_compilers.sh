#!/bin/bash -l
set -euo pipefail

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

environment=$(echo $NODE_LABELS | cut -d '-' -f 1)
echo "Environment $environment"

# Produce a valid list of compilers
set +u
. ${SENV_VIRTUALENV_PATH}/bin/activate
set -u

SPACK_CHECKOUT_DIR=$(senv --input ${STACK_RELEASE}.yaml spack-checkout-dir)

if [ x'${DRY_RUN}' = 'xyes' ]; then
    SPACK="echo ${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="echo jenkins/senv.sh"
else
    SPACK="${SPACK_CHECKOUT_DIR}/bin/spack"
    SENV="jenkins/senv.sh"
fi

# Clean old test results from the workspace
set +e
mv -f compilers.${environment}.xml old_compilers.${environment}.xml
set -e


mkdir -p ${SPACK_CHECKOUT_DIR}/etc/spack/licenses/intel
cp external/intel/licenses/scitas_license.lic \
    ${SPACK_CHECKOUT_DIR}/etc/spack/licenses/intel/license.lic

echo "#### List compilers to install:"
jenkins/senv.sh list-compilers \
    --env $environment \
    --all > list_${environment}_compilers.txt
cat list_${environment}_compilers.txt

# Source Spack and add the system compiler
${SPACK} --version

compilers_to_install=$(cat list_${environment}_compilers.txt | sort -u)
${SPACK} --env ${environment} spec -Ilt ${compilers_to_install}
${SPACK} --env ${environment} install -v --log-format=junit --log-file=compilers.${environment}.xml ${compilers_to_install}

${SPACK} --env ${environment} module lmod refresh -y ${compilers_to_install}

#${SPACK} --env ${environment}  module lmod refresh --yes
echo "#### Setting stable compilers as default"
jenkins/senv.sh list-compilers \
    --env ${environment} \
    --stack-type stable | xargs -L1 ${SPACK} --env ${environment}  module lmod setdefault
