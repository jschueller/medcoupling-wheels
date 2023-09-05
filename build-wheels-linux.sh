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

# med
MED_VERSION=4.1.1
curl -fSsL https://files.salome-platform.org/Salome/other/med-${MED_VERSION}.tar.gz | tar xz
cmake -S med-${MED_VERSION}_SRC -B build_med -LAH -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PWD/install \
  -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF -DHDF5_DIR=$PWD/install/share/cmake/hdf5 \
  -DCMAKE_INSTALL_RPATH="${PWD}/install/lib;/usr/local/lib" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build build_med --target install

# configuration
git clone --depth 1 -b V`echo ${VERSION}|sed "s|\.|_|g"` https://git.salome-platform.org/gitpub/tools/configuration.git

# medcoupling
pip install scipy
git clone --depth 1 -b V`echo ${VERSION}|sed "s|\.|_|g"` http://git.salome-platform.org/gitpub/tools/medcoupling.git
sed -i "s|PYTHON_LIBRARIES|ZZZ|g" medcoupling/src/{MEDCoupling_Swig,MEDPartitioner_Swig,MEDLoader/Swig,PyWrapping,RENUMBER_Swig,ParaMEDMEM_Swig}/CMakeLists.txt  # dont explicitely link Python libs for Unix wheels
cmake -S medcoupling -B build_medcoupling -LAH -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PWD/install \
  -DMEDCOUPLING_BUILD_DOC=OFF -DMEDCOUPLING_BUILD_TESTS=OFF -DCONFIGURATION_ROOT_DIR=$PWD/configuration \
  -DPYTHON_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
  -DPYTHON_INCLUDE_DIR=/opt/python/${PYTAG}-${ABI}/include/python${PYVERD} -DPYTHON_LIBRARY=dummy \
  -DMEDCOUPLING_PARTITIONER_SCOTCH=OFF -DMEDCOUPLING_USE_64BIT_IDS=OFF \
  -DCMAKE_INSTALL_RPATH="${PWD}/install/lib;/usr/local/lib" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build build_medcoupling --target install

cd install/lib/python*/site-packages
rm -rf __pycache__

# write metadata
mkdir medcoupling-${VERSION}.dist-info
sed "s|@PACKAGE_VERSION@|${VERSION}|g" ${SCRIPTPATH}/METADATA.in > medcoupling-${VERSION}.dist-info/METADATA
echo -e "Wheel-Version: 1.0" > medcoupling-${VERSION}.dist-info/WHEEL
for f in `find *.py *.so medcoupling-${VERSION}.dist-info -type f`; do echo "$f,," >> medcoupling-${VERSION}.dist-info/RECORD ; done

# create archive
zip -r medcoupling-${VERSION}-${TAG}.whl *.py *.so medcoupling-${VERSION}.dist-info

auditwheel show medcoupling-${VERSION}-${TAG}.whl
auditwheel repair medcoupling-${VERSION}-${TAG}.whl -w /io/wheelhouse/

# test
cd /tmp
pip uninstall -y scipy
pip install medcoupling --pre --no-index -f /io/wheelhouse
python -c "import medcoupling as mc; print(mc.__version__); mc.ShowAdvancedExtensions()"
python -c "import medcoupling as mc; print(mc.MEDCouplingHasNumPyBindings())"
python -c "import medcoupling as mc; print(mc.MEDCouplingHasSciPyBindings())"
