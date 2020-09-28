#!/usr/bin/env bash

if [ ! -e ${SENV_VIRTUALENV_PATH}/bin/activate ]; then
    ./jenkins/deploy/scripts/update_production_configuration.sh
fi

. ${SENV_VIRTUALENV_PATH}/bin/activate
senv --input ${STACK_RELEASE}.yaml $@
