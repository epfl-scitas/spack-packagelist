FROM centos:7

# Define where spack is installed, and force spack to accept building as root
ENV SPACK_ROOT=/opt/spack \
    FORCE_UNSAFE_CONFIGURE=1

# Pick up the latest updates to the base image
RUN yum upgrade -y && \
    yum clean all && rm -rf /var/cache/yum

# Install the EPEL repository to have LMOD, and install other tools spack needs
RUN yum install -y epel-release && \
    yum clean all && rm -rf /var/cache/yum
RUN yum install -y autoconf automake cmake gcc gcc-c++ gcc-gfortran git make \
                   subversion Lmod patch lbzip2 && \
    yum clean all && rm -rf /var/cache/yum

# Get the current SCITAS release of spack
RUN mkdir $SPACK_ROOT && \
    curl -s -L \
    https://api.github.com/repos/epfl-scitas/spack/tarball/releases/paien \
    | tar xzC $SPACK_ROOT --strip 1

# Login script which enables spack (in a way that it runs after the lmod one)
COPY spack.sh /etc/profile.d/z10_spack.sh

# Pre "add" the system compiler to spack so that it works out-of-the-box
RUN /bin/bash -l -c "spack compiler add"

# Ensure the login scripts are sourced
CMD /bin/bash -l
