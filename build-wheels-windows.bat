@echo on

set VERSION=%1%
set ABI=%2%
set "MED_VERSION=4.1.1"
set PY_VER=%ABI:~2,1%.%ABI:~3%
set PLATFORM="win_amd64"
set PYTAG=%ABI%
set TAG="%PYTAG%-%ABI%-%PLATFORM%"
set SCRIPTPATH="%CD%"

echo "ABI=%ABI%"
echo "PY_VER=%PY_VER%"
echo "PLATFORM=%PLATFORM%"
echo "PYTAG=%PYTAG%"
echo "TAG=%TAG%"
echo "PATH=%PATH%"

set BUILD_DIR="%SCRIPTPATH%\build_dir"
set MEDCOUPLING_BUILD_DIR="%BUILD_DIR%\medcoupling"
set PYTHON_ROOT=%pythonLocation%
python --version
python -m pip install build

call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x86_amd64

:: metis
git clone --depth 1 -b v5.1.1-DistDGL-v0.5 https://github.com/KarypisLab/METIS.git METIS
git clone --depth 1 -b METIS-v5.1.1-DistDGL-0.5 https://github.com/KarypisLab/GKlib.git METIS/GKlib
sed -i "s|//#define IDXTYPEWIDTH 32|#define IDXTYPEWIDTH 32|g" METIS\include\metis.h
sed -i "s|//#define REALTYPEWIDTH 32|#define REALTYPEWIDTH 64|g" METIS\include\metis.h
mkdir METIS\build\windows
mkdir METIS\build\xinclude
copy METIS\include\metis.h METIS\build\xinclude
copy METIS\include\CMakeLists.txt METIS\build\xinclude
cmake -LAH -S METIS -B build_metis -DCMAKE_INSTALL_PREFIX=%BUILD_DIR%/metis -DCMAKE_BUILD_TYPE=Release
cmake --build build_metis --config Release
mkdir %BUILD_DIR%\metis\include
copy METIS\include\metis.h %BUILD_DIR%\metis\include
mkdir %BUILD_DIR%\metis\lib
copy build_metis\libmetis\Release\metis.lib %BUILD_DIR%\metis\lib

:: libxml2
git clone --depth 1 -b v2.10.4 https://github.com/GNOME/libxml2.git libxml2
pushd libxml2\win32
cscript configure.js compiler=msvc iconv=no icu=no zlib=no lzma=no python=no ^
                     prefix=%BUILD_DIR%\libxml2 include=%BUILD_DIR%\libxml2\include lib=%BUILD_DIR%\libxml2\lib
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
    --prefix=%BUILD_DIR%\boost ^
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
    --with-serialization --with-filesystem --with-date_time --with-chrono --with-thread --with-regex --with-system
popd

:: hdf5
git clone --depth 1 -b hdf5-1_10_3 https://github.com/HDFGroup/hdf5.git hdf5
cmake -LAH -S hdf5 -B build_hdf5 -DCMAKE_INSTALL_PREFIX=%BUILD_DIR%/hdf5 -DBUILD_TESTING=OFF -DHDF5_BUILD_TOOLS=OFF -DHDF5_BUILD_EXAMPLES=OFF
cmake --build build_hdf5 --config Release --target install

:: med
REM The download link changed (it's generated after filing a form on salome website)
echo "downloading med"
curl -LO https://files.salome-platform.org/Salome/medfile/med-%MED_VERSION%.tar.gz
echo "ended downloading med"
dir
echo "extracting med"
7z x med-%MED_VERSION%.tar.gz > nul
7z x med-%MED_VERSION%.tar > nul
echo "end extracting med"
dir
cmake -LAH -S med-%MED_VERSION% -B build_med -DCMAKE_INSTALL_PREFIX=%BUILD_DIR%/med -DHDF5_ROOT_DIR=%BUILD_DIR%/hdf5 ^
  -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF
cmake --build build_med --config Release --target install

git clone --depth 1 -b V%VERSION:.=_% https://git.salome-platform.org/gitpub/tools/configuration.git configuration

pip install scipy

git clone --depth 1 -b V%VERSION:.=_% http://git.salome-platform.org/gitpub/tools/medcoupling.git medcoupling
cmake -LAH -S medcoupling -B build_medcoupling -DCMAKE_INSTALL_PREFIX=%BUILD_DIR%/medcoupling ^
  -DMEDFILE_ROOT_DIR=%BUILD_DIR%/med ^
  -DMETIS_ROOT_DIR=%BUILD_DIR%/metis ^
  -DHDF5_ROOT_DIR=%BUILD_DIR%/hdf5 ^
  -DLIBXML2_ROOT_DIR=%BUILD_DIR%/libxml2 ^
  -DBOOST_ROOT_DIR=%BUILD_DIR%/boost ^
  -DMEDCOUPLING_BUILD_DOC=OFF -DMEDCOUPLING_BUILD_TESTS=OFF -DCONFIGURATION_ROOT_DIR=%SCRIPTPATH%/configuration ^
  -DPYTHON_LIBRARY=%PYTHON_ROOT%\libs\python%ABI:~2%.lib -DPYTHON_INCLUDE_DIR=%PYTHON_ROOT%\include ^
  -DPYTHON_EXECUTABLE=%PYTHON_ROOT%\python.exe ^
  -DMEDCOUPLING_PARTITIONER_METIS=OFF -DMEDCOUPLING_PARTITIONER_SCOTCH=OFF -DMEDCOUPLING_PARTITIONER_METIS=ON -DMEDCOUPLING_USE_64BIT_IDS=OFF
cmake --build build_medcoupling --config Release --target install

:: build wheel
xcopy /y %BUILD_DIR%\libxml2\bin\*.dll %MEDCOUPLING_BUILD_DIR%
xcopy /y %BUILD_DIR%\hdf5\bin\hdf5.dll %MEDCOUPLING_BUILD_DIR%
xcopy /y %BUILD_DIR%\med\lib\medC.dll %MEDCOUPLING_BUILD_DIR%
xcopy /y %BUILD_DIR%\medcoupling\lib\*.dll %MEDCOUPLING_BUILD_DIR%
rem  xcopy /y %BUILD_DIR%\boost\lib\*.dll %MEDCOUPLING_BUILD_DIR%

curl -LO https://github.com/lucasg/Dependencies/releases/download/v1.11.1/Dependencies_x64_Release_.without.peview.exe.zip
7z x Dependencies_x64_Release_.without.peview.exe.zip
Dependencies.exe -modules %MEDCOUPLING_BUILD_DIR%\_medcoupling.pyd

cd %SCRIPT_PATH%
echo %MEDCOUPLING_BUILD_DIR%
dir %MEDCOUPLING_BUILD_DIR%


python -m build --wheel .

set WHEEL_FILE="medcoupling-%VERSION%-%ABI%-%ABI%-win_amd64.whl"

copy ".\dist\medcoupling-%VERSION%-py3-none-any.whl" %WHEEL_FILE%

python -m pip install %WHEEL_FILE%

python -c "import medcoupling as mc; print(mc.__version__); mc.ShowAdvancedExtensions()"
python -c "import medcoupling as mc; print(mc.MEDCouplingHasNumPyBindings())"
python -c "import medcoupling as mc; print(mc.MEDCouplingHasSciPyBindings())"
