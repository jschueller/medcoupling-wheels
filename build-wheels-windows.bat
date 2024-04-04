@echo on
set VERSION=%1%
set ABI=%2%
set PY_VER=%ABI:~2,1%.%ABI:~3%

echo "ABI=%ABI%"
echo "PY_VER=%PY_VER%"
echo "PATH=%PATH%"

set PYTHON_ROOT=%pythonLocation%
python --version

call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x86_amd64

:: metis
git clone --depth 1 -b v5.1.1-DistDGL-v0.5 https://github.com/KarypisLab/METIS.git
git clone --depth 1 -b METIS-v5.1.1-DistDGL-0.5 https://github.com/KarypisLab/GKlib.git METIS/GKlib
sed -i "s|//#define IDXTYPEWIDTH 32|#define IDXTYPEWIDTH 32|g" METIS\include\metis.h
sed -i "s|//#define REALTYPEWIDTH 32|#define REALTYPEWIDTH 64|g" METIS\include\metis.h
mkdir METIS\build\windows
mkdir METIS\build\xinclude
copy METIS\include\metis.h METIS\build\xinclude
copy METIS\include\CMakeLists.txt METIS\build\xinclude
cmake -LAH -S METIS -B build_metis -DCMAKE_INSTALL_PREFIX=C:/Libraries/metis -DCMAKE_BUILD_TYPE=Release
cmake --build build_metis --config Release
mkdir C:\Libraries\metis\include
copy METIS\include\metis.h C:\Libraries\metis\include
mkdir C:\Libraries\metis\lib
copy build_metis\libmetis\Release\metis.lib C:\Libraries\metis\lib

:: libxml2
git clone --depth 1 -b v2.10.4 https://github.com/GNOME/libxml2.git
pushd libxml2\win32
cscript configure.js compiler=msvc iconv=no icu=no zlib=no lzma=no python=no ^
                     prefix=C:\Libraries\libxml2 include=C:\Libraries\libxml2\include lib=C:\Libraries\libxml2\lib
nmake /f Makefile.msvc
nmake /f Makefile.msvc install
popd

:: boost
set "BOOST_VERSION=1.80.0"
curl -LO https://boostorg.jfrog.io/artifactory/main/release/%BOOST_VERSION%/source/boost_%BOOST_VERSION:.=_%.zip
7z x boost_%BOOST_VERSION:.=_%.zip > nul
pushd boost_%BOOST_VERSION:.=_%
call bootstrap.bat
.\b2 install ^
    --build-dir=build_boost ^
    --prefix=C:\Libraries\boost ^
    toolset=msvc-14.3 ^
    architecture=x86 ^
    address-model=64 ^
    variant=release ^
    threading=multi ^
    link=shared ^
    -j4 ^
    -s NO_COMPRESSION=1 ^
    -s NO_ZLIB=1 ^
    -s NO_BZIP2=1 ^
    -s ZLIB_INCLUDE=%PREFIX%\Library\include ^
    -s ZLIB_LIBPATH=%PREFIX%\Library\lib ^
    -s ZLIB_BINARY=z ^
    -s BZIP2_INCLUDE=%PREFIX%\Library\include ^
    -s BZIP2_LIBPATH=%PREFIX%\Library\lib ^
    -s BZIP2_BINARY=libbz2 ^
    -s ZSTD_INCLUDE=%PREFIX%\Library\include ^
    -s ZSTD_LIBPATH=%PREFIX%\Library\lib ^
    -s ZSTD_BINARY=zstd ^
    --layout=system ^
    --with-serialization --with-filesystem --with-date_time --with-chrono --with-thread --with-regex --with-system > nul
popd

:: hdf5
git clone --depth 1 -b hdf5-1_10_3 https://github.com/HDFGroup/hdf5.git
cmake -LAH -S hdf5 -B build_hdf5 -DCMAKE_INSTALL_PREFIX=C:/Libraries/hdf5 -DBUILD_TESTING=OFF -DHDF5_BUILD_TOOLS=OFF -DHDF5_BUILD_EXAMPLES=OFF
cmake --build build_hdf5 --config Release --target install

:: med
set "MED_VERSION=4.1.1"
curl -LO https://www.code-saturne.org/releases/external/med-%MED_VERSION%.tar.gz
7z x med-%MED_VERSION%.tar.gz > nul
7z x med-%MED_VERSION%.tar > nul
cmake -LAH -S med-%MED_VERSION%_SRC -B build_med -DCMAKE_INSTALL_PREFIX=C:/Libraries/med -DHDF5_ROOT_DIR=C:/Libraries/hdf5 ^
  -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF
cmake --build build_med --config Release --target install

:: configuration
git clone --depth 1 -b V%VERSION:.=_% https://git.salome-platform.org/gitpub/tools/configuration.git

:: medcoupling
pip install scipy
git clone --depth 1 -b V%VERSION:.=_% https://git.salome-platform.org/gitpub/tools/medcoupling.git
patch -p1 -i %GITHUB_WORKSPACE%\medcoupling913-numpy2.patch -d medcoupling
cmake -LAH -S medcoupling -B build_medcoupling -DCMAKE_INSTALL_PREFIX=C:/Libraries/medcoupling ^
  -DMEDFILE_ROOT_DIR=C:/Libraries/med ^
  -DMETIS_ROOT_DIR=C:/Libraries/metis ^
  -DHDF5_ROOT_DIR=C:/Libraries/hdf5 ^
  -DLIBXML2_ROOT_DIR=C:/Libraries/libxml2 ^
  -DBOOST_ROOT_DIR=C:/Libraries/boost ^
  -DMEDCOUPLING_BUILD_DOC=OFF -DMEDCOUPLING_BUILD_TESTS=OFF -DCONFIGURATION_ROOT_DIR=%CD%/configuration ^
  -DPYTHON_LIBRARY=%PYTHON_ROOT%\libs\python%ABI:~2%.lib -DPYTHON_INCLUDE_DIR=%PYTHON_ROOT%\include ^
  -DPYTHON_EXECUTABLE=%PYTHON_ROOT%\python.exe ^
  -DMEDCOUPLING_PARTITIONER_METIS=OFF -DMEDCOUPLING_PARTITIONER_SCOTCH=OFF -DMEDCOUPLING_PARTITIONER_METIS=ON -DMEDCOUPLING_USE_64BIT_IDS=OFF
cmake --build build_medcoupling --config Release --target install

:: build wheel
xcopy /y C:\Libraries\libxml2\bin\*.dll C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
xcopy /y C:\Libraries\hdf5\bin\hdf5.dll C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
xcopy /y C:\Libraries\med\lib\medC.dll C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
xcopy /y C:\Libraries\medcoupling\lib\*.dll C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
rem  xcopy /y C:\Libraries\boost\lib\*.dll C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages

curl -LO https://github.com/lucasg/Dependencies/releases/download/v1.11.1/Dependencies_x64_Release_.without.peview.exe.zip
7z x Dependencies_x64_Release_.without.peview.exe.zip
Dependencies.exe -modules C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages\_medcoupling.pyd

pushd C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
mkdir medcoupling-%VERSION%.dist-info
sed "s|@PACKAGE_VERSION@|%VERSION%|g" %GITHUB_WORKSPACE%\METADATA.in > medcoupling-%VERSION%.dist-info\METADATA
python %GITHUB_WORKSPACE%\write_distinfo.py medcoupling %VERSION% %ABI%-%ABI%-win_amd64

type medcoupling-%VERSION%.dist-info\METADATA
type medcoupling-%VERSION%.dist-info\WHEEL

mkdir %GITHUB_WORKSPACE%\wheelhouse
7z a -tzip %GITHUB_WORKSPACE%\wheelhouse\medcoupling-%VERSION%-%ABI%-%ABI%-win_amd64.whl *.py *.pyd *.dll medcoupling-%VERSION%.dist-info
pip install %GITHUB_WORKSPACE%\wheelhouse\medcoupling-%VERSION%-%ABI%-%ABI%-win_amd64.whl
pushd %GITHUB_WORKSPACE%

python -c "import medcoupling as mc; print(mc.__version__); mc.ShowAdvancedExtensions()"
python -c "import medcoupling as mc; print(mc.MEDCouplingHasNumPyBindings())"
python -c "import medcoupling as mc; print(mc.MEDCouplingHasSciPyBindings())"
python .\medcoupling\src\MEDCoupling_Swig\MEDCouplingNumPyTest.py
