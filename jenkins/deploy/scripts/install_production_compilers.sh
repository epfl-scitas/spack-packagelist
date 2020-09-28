#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SENV_VIRTUALENV_PATH: path where to find the virtualenv for "senv"
# SPACK_CHECKOUT_DIR: path where Spack was cloned
#

environment=$1

if [ x'${DRY_RUN}' != 'x' ]; then
    SPACK='echo spack'
    SENV='echo senv'
else
    SPACK='spack'
    SENV='senv'
fi

# Clean old test results from the workspace
mv -f compilers.${environment}.xml old_compilers.${environment}.xml

# Produce a valid list of compilers
. ${SENV_VIRTUALENV_PATH}/bin/activate
senv --input ${STACK_RELEASE}.yaml \
    list-compilers \
    --env $environment > list_compilers.txt

if [ ! -e ${SPACK_CHECKOUT_DIR}/var/environments/${environment}/spack.yaml ]; then
    spack env create ${environment}
fi

senv --input ${STACK_RELEASE}.yaml \
    create-env \
    --env $environment


# Source Spack and add the system compiler
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
spack --version

cat list_compilers.txt | xargs -L ${SPACK} --env ${environment} install --log-format=junit --log-file=compilers.${environment}.xml

senv --input ${STACK_RELEASE}.yaml list-compilers --env ${environment} --stack-type stable | xargs -L1 ${SPACK} module lmod setdefault

# to reconfigure the compilers.yaml
${SENV} --input ${STACK_RELEASE}.yaml install-spack-default-configuration

# this has to be changed once we have a stack similar on all machines otherwhy the config file will be rewriten for each environment
${SENV} --input ${STACK_RELEASE}.yaml intel-compilers-configuration --env ${environment}

deactivate
