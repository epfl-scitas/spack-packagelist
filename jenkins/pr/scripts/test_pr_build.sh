#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SPACK_PRODUCTION_DIR: path where the production instance of Spack resides
#

# Configure ccache properly. Caches are kept separated among different targets.
ccache_config_dir="${HOME}/.ccache/${SPACK_TARGET_TYPE}"
ccache_cache_dir="/scratch/scitasbuild/ccache/${SPACK_TARGET_TYPE}"

mkdir -p ${ccache_config_dir}
mkdir -p ${ccache_cache_dir}

export CCACHE_CONFIGPATH=${ccache_config_dir}/ccache.conf

cat > ${CCACHE_CONFIGPATH} <<EOF
max_size = 100.0G
cache_dir = ${ccache_cache_dir}
temporary_dir = /tmp/ccache/${SPACK_TARGET_TYPE}
EOF

# Print configuration
ccache -p

# Zero-out statistics
ccache -z

# Retrieve which Spack instance we need to use for the build
SPACK_CHECKOUT_DIR=$(cat spack_dir.txt)

# Try to install the specs
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh

# We need to install Intel to have the intel module available
# in the temporary workspace
spack install intel@18.0.5 %gcc@4.8.5
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh

# Print out information that could be useful for logging and debugging
which spack
spack mirror list
spack config get config

specs_to_be_installed=$(cat to_be_installed.${SPACK_TARGET_TYPE}.txt)

if [[ -z "${specs_to_be_installed}" ]]
then
    echo "[${SPACK_TARGET_TYPE}] Nothing to install"
    cp resources/success.xml spec.${SPACK_TARGET_TYPE}.xml
else
    spack install --log-file=spec.${SPACK_TARGET_TYPE}.xml --log-format=junit ${specs_to_be_installed}
fi

# Show ccache statistics
ccache -s

# Activate python extensions

## Deactivated due to https://github.com/spack/spack/issues/13268

## # Set the line separator to be only the newline character
## #
## # https://askubuntu.com/questions/344407/how-to-read-complete-line-in-for-loop-with-spaces
## # https://unix.stackexchange.com/questions/16192/what-is-the-ifs
## #
## IFS=$'\n'
## for spec in $(cat to_be_installed.${SPACK_TARGET_TYPE}.txt)
## do
##     # Activate python extensions
##     if [[ "${spec}" =~ ^py- ]]
##     then
##         echo "[ACTIVATION] ${spec}"
##         spack activate ${spec}
##     fi
## done
