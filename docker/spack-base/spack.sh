source $SPACK_ROOT/share/spack/setup-env.sh

if [ -d $SPACK_ROOT/share/spack/lmod/ ]; then
    module use $SPACK_ROOT/share/spack/lmod/
fi
