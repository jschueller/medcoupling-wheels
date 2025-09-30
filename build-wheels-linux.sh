#!/bin/sh

set -e -x

test $# = 2 || exit 1

VERSION="$1"
ABI="$2"

PLATFORM=manylinux2014_x86_64
PYTAG=${ABI/m/}
TAG=${PYTAG}-${ABI}-${PLATFORM}
PYVERD=${ABI:2:1}.${ABI:3}

SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`
export PATH=/opt/python/${PYTAG}-${ABI}/bin/:$PATH

cd /tmp

# configuration
SALOME_VERSION=`echo "V${VERSION}"|sed "s|\.|_|g"`
git clone --depth 1 -b ${SALOME_VERSION} https://github.com/SalomePlatform/configuration.git

# medcoupling
VERSION=9.16.0dev0
GIT_COMMIT=123ce02
pip install scipy
git clone --depth 100 https://github.com/SalomePlatform/medcoupling.git
cd medcoupling
git checkout ${GIT_COMMIT}
cd ..
cmake -LAH -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$PWD/install \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DMEDCOUPLING_BUILD_DOC=OFF -DMEDCOUPLING_BUILD_TESTS=OFF -DCONFIGURATION_ROOT_DIR=$PWD/configuration \
  -DPYTHON_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
  -DPYTHON_INCLUDE_DIR=/opt/python/${PYTAG}-${ABI}/include/python${PYVERD} -DPYTHON_LIBRARY=dummy \
  -DMEDCOUPLING_PARTITIONER_SCOTCH=OFF -DMEDCOUPLING_USE_64BIT_IDS=ON \
  -DCMAKE_INSTALL_RPATH="${PWD}/install/lib;/usr/local/lib" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -B build_medcoupling -S medcoupling
cmake --build build_medcoupling --target install

cd install/lib/python*/site-packages
rm -rf __pycache__

# write metadata
mkdir medcoupling-${VERSION}.dist-info
sed "s|@PACKAGE_VERSION@|${VERSION}|g" ${SCRIPTPATH}/METADATA.in > medcoupling-${VERSION}.dist-info/METADATA
python ${SCRIPTPATH}/write_distinfo.py medcoupling ${VERSION} ${TAG}

# create archive
zip -r medcoupling-${VERSION}-${TAG}.whl *.py *.so medcoupling-${VERSION}.dist-info

auditwheel show medcoupling-${VERSION}-${TAG}.whl
auditwheel repair medcoupling-${VERSION}-${TAG}.whl -w /io/wheelhouse/

# test
cd /tmp
pip install medcoupling --pre --no-index -f /io/wheelhouse
python -c "import medcoupling as mc; print(mc.__version__); mc.ShowAdvancedExtensions()"
python -c "import medcoupling as mc; assert mc.MEDCouplingHasNumPyBindings()"
python -c "import medcoupling as mc; assert mc.MEDCouplingHasSciPyBindings()"
python -c "import medcoupling as mc; assert mc.MEDCouplingSizeOfIDs() == 64"
python ./medcoupling/src/MEDCoupling_Swig/MEDCouplingNumPyTest.py
