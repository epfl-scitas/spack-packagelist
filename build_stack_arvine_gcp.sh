#!/bin/bash
set -euo pipefail
export DRY_RUN='no'
export STACK_RELEASE="arvine-gcp"
export SENV_VIRTUALENV_PATH="${HOME}/${STACK_RELEASE}/virtualenv/senv-py27"

# Create virtual env
./jenkins/deploy/scripts/update_production_configuration.sh

# Do some checks
./jenkins/senv.sh status
./jenkins/senv.sh spack-checkout
./jenkins/senv.sh spack-checkout-extra-repos
env | sort

# Create the environments
./jenkins/deploy/scripts/create_environments.sh yes

# Install compilers
for env in $(senv --input arvine-gcp.yaml list-envs)
do
    ./jenkins/deploy/scripts/install_production_compilers.sh ${env}
done

# Finish creating the environements
./jenkins/deploy/scripts/create_environments.sh no

# Concretize the environements
for env in $(senv --input arvine-gcp.yaml list-envs)
do
    ./jenkins/deploy/scripts/concretize.sh ${env}
done

# Fetch to the mirror
./jenkins/deploy/scripts/populate_mirror.sh

# Install and activates the packages
for env in $(senv --input arvine-gcp.yaml list-envs)
do
    ./jenkins/deploy/scripts/install_production_stack.sh ${env}
    ./jenkins/deploy/scripts/activate_packages.sh ${env}
done
