#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SPACK_PRODUCTION_DIR: path where the production instance of Spack resides
#

# Configure ccache properly. Caches are kept separated among different targets.
mkdir -p ~/.ccache/${SPACK_TARGET_TYPE}
mkdir -p /scratch/scitasbuild/ccache/${SPACK_TARGET_TYPE}

export CCACHE_CONFIGPATH=~/.ccache/${SPACK_TARGET_TYPE}/ccache.conf

cat > ${CCACHE_CONFIGPATH} <<EOF
max_size = 100.0G
cache_dir = /scratch/scitasbuild/ccache/${SPACK_TARGET_TYPE}
EOF

# Zero-out statistics
ccache -z

# Retrieve which Spack instance we need to use for the build
SPACK_CHECKOUT_DIR=$(cat spack_dir.txt)

# Try to install the specs
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh

# We need to install Intel to have the intel module available
# in the temporary workspace
spack install intel@18.0.2 %gcc@4.8.5
. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
which spack
spack mirror list

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

# Set the line separator to be only the newline character
#
# https://askubuntu.com/questions/344407/how-to-read-complete-line-in-for-loop-with-spaces
# https://unix.stackexchange.com/questions/16192/what-is-the-ifs
#
IFS=$'\n'
for spec in $(cat to_be_installed.${SPACK_TARGET_TYPE}.txt)
do
    # Activate python extensions
    if [[ "${spec}" =~ ^py- ]]
    then
        echo "[ACTIVATION] ${spec}"
        spack activate ${spec}
    fi
done
