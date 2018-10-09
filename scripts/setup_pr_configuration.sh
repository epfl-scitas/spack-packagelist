#!/bin/bash -l

# This script assumes that the following variables are set in the environment:
#
# SPACK_PRODUCTION_DIR: path where the production instance of Spack resides
#


# If a branch exists in epfl-scitas/spack with the same name as the one
# checked-out for spack-packagelist, use that one. Otherwise use the HEAD
# of the release branch

SPACK_BRANCH_NAME=$(git ls-remote --heads https://github.com/epfl-scitas/spack.git ${GIT_BRANCH})
if [[ -z ${SPACK_BRANCH_NAME} ]]
then
    SPACK_BRANCH_NAME="releases/paien"
else
    SPACK_BRANCH_NAME="${GIT_BRANCH}"
fi
echo "[SPACK_BRANCH_NAME] ${SPACK_BRANCH_NAME}"

# Create a temporary directory to work in and clone Spack
SPACK_CHECKOUT_DIR=$(mktemp -d /home/scitasbuild/paien/pr/spack.XXXXX)
SPACK_MIRROR_DIR=$(mktemp -d /home/scitasbuild/paien/pr/spack-mirror.XXXXX)
echo "[SPACK WORKSPACE] ${SPACK_CHECKOUT_DIR}"
git clone -b "${SPACK_BRANCH_NAME}" https://github.com/epfl-scitas/spack.git "${SPACK_CHECKOUT_DIR}"

# Output the workspace dir to a file that will be stashed
echo "${SPACK_CHECKOUT_DIR}" > spack_dir.txt

# Copy the configuration files in, link the compilers
cp -v configuration/* ${SPACK_CHECKOUT_DIR}/etc/spack/
cd ${SPACK_CHECKOUT_DIR}/etc/spack/
ln -s /ssoft/spack/paien/spack.v2/etc/spack/compilers.yaml compilers.yaml
# Remove config.yaml, as it point to install things directly in production
rm config.yaml
cd -

# Create a virtual env for the command just checked out
SENV_VIRTUALENV_PATH=$(mktemp -d /home/scitasbuild/paien/pr/senv.XXXXX)
virtualenv -p $(which python) ${SENV_VIRTUALENV_PATH} --clear
. ${SENV_VIRTUALENV_PATH}/bin/activate
pip install --force-reinstall -U .
deactivate

# Activate the helper command and production Spack. Then
# compute what still needs to be installed.

# TODO: the logic here can be improved later, to also
# TODO: check what's in the PR

. ${SPACK_PRODUCTION_DIR}/share/spack/setup-env.sh
which spack

. ${SENV_VIRTUALENV_PATH}/bin/activate
senv --help
# Generate the list of software that need to be installed, then fetch every tarball

# For this part we currently need to work with the production instance of Spack,
# as we need to query which software was already installed
targets="$(senv targets)"
original_arch="${SPACK_TARGET_TYPE}"

for target in ${targets}
do
    echo "[${target}] Computing list of packages to be tested"
    senv packages ${target} --output="all_specs.${target}.txt"

    # TODO: if concretization is slow this command could output also the yaml file

    # FIXME: Spack apparently has a bug in the string representation of Specs,
    # FIXME: so we need to force SPACK_TARGET_TYPE to be the target we are
    # FIXME: querying if we don't want false positives with mixed targets in
    # FIXME: concretized the spec
    SPACK_TARGET_TYPE="${target}" spack filter --not-installed --output to_be_installed.${target}.txt $(cat all_specs.${target}.txt)
    if [ $? -ne 0 ]
    then
        echo "[${target}] ERROR while computing list of packages!"
        exit 1
    fi
    echo "[${target}] $(cat to_be_installed.${target}.txt)"

done
deactivate

# Add the mirror to the temporary Spack instance

. ${SPACK_CHECKOUT_DIR}/share/spack/setup-env.sh
which spack

for target in ${targets}
do
    # TODO: read directly from a yaml file to avoid concretization slowdowns
    echo "[${target}] Populating temporary mirror"
    while read -r line
    do
        echo "spack mirror create -D -d ${SPACK_MIRROR_DIR} ${line}"
        SPACK_TARGET_TYPE="${target}" spack mirror create -D -d ${SPACK_MIRROR_DIR} ${line}

        # Exit with an error if mirror failed
        if [[ "$?" != 0 ]] ; then exit 1 ; fi

    done < to_be_installed.${target}.txt
done
spack mirror add --scope=site temp_mirror ${SPACK_MIRROR_DIR}

# Add the central repository. This is needed for licensed software that has
# to be built from sources and must be downloaded manually.
spack mirror add --scope=site central_mirror /ssoft/spack/mirror
