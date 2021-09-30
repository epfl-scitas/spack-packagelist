#!/bin/bash
set -euo pipefail
export DRY_RUN='yes'
export STACK_RELEASE="arvine"
export SENV_VIRTUALENV_PATH="${HOME}/${STACK_RELEASE}/virtualenv/senv-py36"
export SPACK_PYTHON=python3.6

#export STACK_PREFIX=/home/richart/spack
#export SENV_OVERRIDE=""
export SENV_OVERRIDE='{"spack_root": "/home/richart/spack"}'

# Create virtual env
./jenkins/deploy/scripts/update_production_configuration.sh

# Do some checks
./jenkins/senv.sh status

./jenkins/senv.sh spack-checkout
./jenkins/senv.sh spack-checkout-extra-repos
env | sort

# Create the environments
./jenkins/deploy/scripts/create_environments.sh yes

env_spack="fidis"
export NODE_LABELS="${env_spack}-toto"
# Install compilers
#for env in $(senv --input ${STACK_RELEASE}.yaml list-envs)
#do
./jenkins/deploy/scripts/install_production_compilers.sh ${env_spack}
#done

# Finish creating the environements
./jenkins/deploy/scripts/create_environments.sh no

# Concretize the environements
#for env in $(senv --input ${STACK_RELEASE}.yaml list-envs)
#do
./jenkins/deploy/scripts/concretize.sh ${env_spack}
#done

# Fetch to the mirror
./jenkins/deploy/scripts/populate_mirror.sh

# Install and activates the packages
#for env in $(senv --input ${STACK_RELEASE}.yaml list-envs)
#do
./jenkins/deploy/scripts/install_production_stack.sh ${env_spack}
./jenkins/deploy/scripts/activate_packages.sh ${env_spack}
#done
