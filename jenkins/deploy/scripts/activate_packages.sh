#!/usr/bin/env bash
set -euo pipefail

# Produce a valid list of compilers
. ${SENV_VIRTUALENV_PATH}/bin/activate

senv --input ${STACK_RELEASE}.yaml list-spec-to-activate --env ${environment}  | xargs -L1 spack activate

deactivate
