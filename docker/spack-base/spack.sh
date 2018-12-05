source $SPACK_ROOT/share/spack/setup-env.sh

SPACK_CORE_MODULES=$SPACK_ROOT/share/spack/lmod/linux-centos7-x86_64/Core
if [ -d $SPACK_CORE_MODULES ]; then
    module use $SPACK_CORE_MODULES
fi
