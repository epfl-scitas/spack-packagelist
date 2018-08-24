FROM centos:7

ENV SPACK_ROOT=/opt/spack \
    FORCE_UNSAFE_CONFIGURE=1

RUN yum upgrade -y && \
    yum clean all && rm -rf /var/cache/yum

# To have a system Lmod out of the box
RUN yum install -y epel-release && \
    yum clean all && rm -rf /var/cache/yum

RUN yum install -y autoconf automake cmake gcc gcc-c++ gcc-gfortran git make subversion Lmod patch lbzip2 && \
    yum clean all && rm -rf /var/cache/yum

RUN mkdir $SPACK_ROOT && \
    curl -s -L \
    https://api.github.com/repos/epfl-scitas/spack/tarball/releases/paien \
    | tar xzC $SPACK_ROOT --strip 1

COPY spack.sh /etc/profile.d/z10_spack.sh

RUN /bin/bash -l -c "spack compiler add"

CMD /bin/bash -l

