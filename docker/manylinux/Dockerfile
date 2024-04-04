
FROM quay.io/pypa/manylinux2014_x86_64
MAINTAINER jschueller

ENV MAKEFLAGS -j8
WORKDIR /usr/local/src

RUN yum install -y zip

# hdf5
RUN curl -fsSL https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.3/src/hdf5-1.10.3.tar.bz2 | tar xj && cd hdf5-1.10.3 && ./configure --enable-cxx --prefix=/usr/local --disable-tests --disable-tools && make > /dev/null 2>&1 && make install > /dev/null 2>&1 && cd - && rm -r hdf5*

# metis
RUN curl -fsSL https://bitbucket.org/petsc/pkg-metis/get/v5.1.0-p10.tar.bz2 | tar xj && cd petsc-pkg-metis-* && make config shared=1 > /dev/null 2>&1 && make install > /dev/null 2>&1 && cd - && rm -r petsc*

# boost
RUN curl -fSsL https://boostorg.jfrog.io/artifactory/main/release/1.81.0/source/boost_1_81_0.tar.bz2 | tar xj && cd boost_1_81_0 \
 && ./bootstrap.sh --with-toolset=gcc --with-icu --with-python=/usr/local/bin/python \
 && ./b2 -q variant=release address-model=64 architecture=x86 debug-symbols=off threading=multi runtime-link=shared link=shared toolset=gcc --layout=system ${MAKEFLAGS} install --with-serialization --with-filesystem --with-date_time --with-chrono --with-thread --with-regex --with-system  > /dev/null 2>&1 && cd - && rm -r boost*

# libxml2
RUN curl -fsSL https://download.gnome.org/sources/libxml2/2.10/libxml2-2.10.3.tar.xz | tar xJ && cd libxml2-2.10.3 \
 && ./configure --without-python && make > /dev/null 2>&1 && make install > /dev/null 2>&1 && cd - && rm -r libxml2*

# med
RUN curl -fSsL https://www.code-saturne.org/releases/external/med-4.1.1.tar.gz | tar xz \
 && cmake -S med-4.1.1_SRC -B build_med -LAH -DCMAKE_BUILD_TYPE=Release \
      -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF -DHDF5_DIR=$PWD/install/share/cmake/hdf5 \
 && cmake --build build_med --target install
