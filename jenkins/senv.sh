#!/usr/bin/env bash

. ${SENV_VIRTUALENV_PATH}/bin/activate
senv --input ${STACK_RELEASE}.yaml $@
