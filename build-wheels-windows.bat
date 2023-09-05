set VERSION=%1%
set ABI=%2%
set PY_VER=%ABI:~2,1%.%ABI:~3%

@echo on
echo "ABI=%ABI%"
echo "PY_VER=%PY_VER%"
echo "PATH=%PATH%"

choco install swig python%ABI:~2%
for /D %%d in (C:\hostedtoolcache\windows\Python\%PY_VER%.*) do (
  set PYTHON_ROOT=%%d\x64
)
set "PATH=%PYTHON_ROOT%;%PYTHON_ROOT%\Scripts;%PATH%"
python --version

:: hdf5
git clone -b hdf5-1_10_3 https://github.com/HDFGroup/hdf5.git
cmake -LAH -S hdf5 -B build_hdf5 -DCMAKE_INSTALL_PREFIX=C:/Libraries/hdf5 -DBUILD_TESTING=OFF -DHDF5_BUILD_TOOLS=OFF -DHDF5_BUILD_EXAMPLES=OFF
cmake --build build_hdf5 --config Release --target install

:: med
set "MED_VERSION=4.1.1"
curl -LO https://files.salome-platform.org/Salome/other/med-%MED_VERSION%.tar.gz
7z x med-%MED_VERSION%.tar.gz > nul
dir /p
7z x med-%MED_VERSION%.tar > nul
dir /p
cmake -LAH -S med-%MED_VERSION%_SRC -B build_med -DCMAKE_INSTALL_PREFIX=C:/Libraries/med -DHDF5_ROOT_DIR=C:/Libraries/hdf5 ^
  -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF
cmake --build build_med --config Release --target install


git clone --depth 1 -b V%VERSION:.=_% https://git.salome-platform.org/gitpub/tools/configuration.git

pip install scipy

git clone --depth 1 -b V%VERSION:.=_% http://git.salome-platform.org/gitpub/tools/medcoupling.git
cmake -LAH -S medcoupling -B build_med -DCMAKE_INSTALL_PREFIX=C:/Libraries/medcoupling -DHDF5_ROOT_DIR=C:/Libraries/hdf5 ^
  -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF
cmake --build build_medcoupling --config Release --target install

:: build wheel
xcopy /y /f C:\Libraries\hdf5\bin\hdf5*.dll C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
xcopy /y /f C:\Libraries\med\lib\*.dll C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
xcopy /y /f C:\Libraries\medcoupling\lib\*.dll C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
pushd C:\Libraries\medcoupling\lib\python%PY_VER%\site-packages
mkdir medcoupling-%VERSION%.dist-info
sed "s|@PACKAGE_VERSION@|%VERSION%|g" %GITHUB_WORKSPACE%\METADATA.in > medcoupling-%VERSION%.dist-info\METADATA
type medcoupling-%VERSION%.dist-info\METADATA
echo Wheel-Version: 1.0 > medcoupling-%VERSION%.dist-info\WHEEL
echo "medcoupling-%VERSION%.dist-info\RECORD,," > medcoupling-%VERSION%.dist-info\RECORD
mkdir %GITHUB_WORKSPACE%\wheelhouse
7z a -tzip %GITHUB_WORKSPACE%\wheelhouse\medcoupling-%VERSION%-%ABI%-%ABI%-win_amd64.whl *.py *.pyd medcoupling-%VERSION%.dist-info
pip install %GITHUB_WORKSPACE%\wheelhouse\medcoupling-%VERSION%-%ABI%-%ABI%-win_amd64.whl
pushd %GITHUB_WORKSPACE%
python -c "import medcoupling as mc; print(mc.__version__); mc.ShowAdvancedExtensions()"
