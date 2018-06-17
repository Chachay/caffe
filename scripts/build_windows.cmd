@echo off
@setlocal EnableDelayedExpansion

if NOT DEFINED MSVC_VERSION set MSVC_VERSION=14
if NOT DEFINED CPU_ONLY set CPU_ONLY=0
if NOT DEFINED WITH_CUDA set WITH_CUDA=1
if NOT DEFINED VCPKG_DIR set VCPKG_DIR=C:\tools\vcpkg\installed\x64-windows
if NOT DEFINED BUILD_PYTHON set BUILD_PYTHON=1
if NOT DEFINED CMAKE_CONFIG set CMAKE_CONFIG=Release
if NOT DEFINED USE_NCCL set USE_NCCL=0
if NOT DEFINED USE_PREBUILD_VCPKG set USE_PREBUILD_VCPKG=1

SET VCPKG_CMAKE=c:/tools/vcpkg/scripts/buildsystems/vcpkg.cmake 

if DEFINED APPVEYOR (
    echo Setting Appveryor Default
    if !PYTHON_VERSION! EQU 2 (
        set CONDA_ROOT=C:\Miniconda-x64
    )
    set PATH=!CONDA_ROOT!;!CONDA_ROOT!\Scripts;!CONDA_ROOT!\Library\bin;!PATH!
    python --version
    conda config --add channels conda-forge
    conda install --yes cmake numpy scipy ^
                        six scikit-image ^
                        pyyaml graphviz
    if ERRORLEVEL 1  (
      echo ERROR: Conda update or install failed
      exit /b 1
    )
    pip install protobuf==3.1.0 pydotplus==2.0.2
    if ERRORLEVEL 1  (
      echo ERROR: PIP update or install failed
      exit /b 1
    )
    echo VCPKG
    if !USE_PREBUILD_VCPKG! == 1 (
        echo Downloding prebuild VCPKG
        appveyor DownloadFile https://www.dropbox.com/s/jtbg71wd0wpqela/vcpkg-export-20180618-002652.zip?dl=1 -FileName pvcpkg.zip

        7z x pvcpkg.zip -oc:\tools

        set VCPKG_CMAKE=c:\tools\vcpkg-export-20180618-002652\scripts\buildsystems\vcpkg.cmake 
    ) else (
        vcpkg install ^
                    glog:x64-windows ^
                    gflags:x64-windows ^
                    lmdb:x64-windows ^
                    leveldb:x64-windows ^
                    snappy:x64-windows ^
                    protobuf:x64-windows ^
                    hdf5:x64-windows ^
                    opencv:x64-windows ^
                    openblas:x64-windows ^
                    zlib:x64-windows ^
                    libjpeg-turbo:x64-windows ^
                    boost-system:x64-windows ^
                    boost-thread:x64-windows ^
                    boost-filesystem:x64-windows ^
                    boost-regex:x64-windows
                    REM boost:x64-windows
    )
    if ERRORLEVEL 1  (
      echo ERROR: vcpkg update or install failed
      exit /b 1
    )
    if !WITH_CUDA! == 1 (
        REM ---------------------------------------
        REM  Install CUDA Toolkit 8.0 on appveyor
        REM ---------------------------------------
        echo Downloading CUDA toolkit 8 ...
        appveyor DownloadFile  https://developer.nvidia.com/compute/cuda/8.0/prod/local_installers/cuda_8.0.44_windows-exe -FileName setup.exe
        echo Installing CUDA toolkit 8 ...
        setup.exe -s compiler_8.0 ^
                                cublas_8.0 ^
                                cublas_dev_8.0 ^
                                cudart_8.0 ^
                                curand_8.0 ^
                                curand_dev_8.0 ^
                                nvml_dev_8.0

        if NOT EXIST "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\bin\cudart64_80.dll" ( 
                echo "Failed to install CUDA"
            exit /B 1
        )
        echo Downloading cuDNN
        appveyor DownloadFile http://developer.download.nvidia.com/compute/redist/cudnn/v5.1/cudnn-8.0-windows10-x64-v5.1.zip -FileName cudnn-8.0-windows7-x64-v5.1.zip

        7z x cudnn-8.0-windows7-x64-v5.1.zip -ocudnn
                                
        copy cudnn\cuda\bin\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\bin"
        copy cudnn\cuda\lib\x64\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\lib\x64"
        copy cudnn\cuda\include\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\include"

        set PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\bin;!PATH!
        set CUDA_PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0
        set CUDA_PATH_V8_0=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0

        nvcc -V

        cd "!APPVEYOR_BUILD_FOLDER!"
        REM ---------------------------------------
        set CPU_ONLY=0
        set RUN_TESTS=0
    ) else (
        set CPU_ONLY=1
    )
    if "%CMAKE_CONFIG%" == "Debug" (
        echo Disabling tests on appveyor with config == %CMAKE_CONFIG%
        set RUN_TESTS=0
    )

    REM SET LMDB_DIR=%VCPKGDIR%
    REM SET LEVELDB_ROOT=%VCPKGDIR%
    REM SET OpenBLAS=%VCPKGDIR%
)

REM Variables to get Visual Studio 2017 installation path
set VC2017_KEY_NAME="HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7"
set VC2017_VALUE_NAME=15.0

REM Call vcvarsall.bat
if "%MSVC_VERSION%"=="15" (
    for /F "usebackq tokens=1,2,*" %%A in (`REG QUERY %VC2017_KEY_NAME% /v %VC2017_VALUE_NAME%`) do (
        set batch_file=%%CVC\Auxiliary\Build\vcvarsall.bat
    )
) else (
    set batch_file=!VS%MSVC_VERSION%0COMNTOOLS!..\..\VC\vcvarsall.bat
)
call "%batch_file%" %processor_architecture%

REM Generator Names
if "%MSVC_VERSION%"=="14" (
    if "%processor_architecture%" == "AMD64" (
        set CMAKE_GENERATOR=Visual Studio 14 2015 Win64
    ) else (
        set CMAKE_GENERATOR=Visual Studio 14 2015
    )
) else if "%MSVC_VERSION%"=="12" (
    if "%processor_architecture%" == "AMD64" (
        set CMAKE_GENERATOR=Visual Studio 12 2013 Win64
    ) else (
        set CMAKE_GENERATOR=Visual Studio 12 2013
    )
) else if "%MSVC_VERSION%"=="15" (
    if "%processor_architecture%" == "AMD64" (
        set CMAKE_GENERATOR=Visual Studio 15 2017 Win64
    ) else (
        set CMAKE_GENERATOR=Visual Studio 15 2017
    )
) else if  "%MSVC_VERSION%"=="9" (
    if "%processor_architecture%" == "AMD64" (
        set CMAKE_GENERATOR=Visual Studio 9 2008 Win64
    ) else (
        set CMAKE_GENERATOR=Visual Studio 9 2008
    )
)
if NOT EXIST build mkdir build
pushd build

cmake -G"!CMAKE_GENERATOR!" ^
      -DCMAKE_TOOLCHAIN_FILE=!VCPKG_CMAKE! ^
      -DBLAS=Open ^
      -DBUILD_python:BOOL=%BUILD_PYTHON% ^
      -DUSE_NCCL:BOOL=!USE_NCCL! ^
      -DCOPY_PREREQUISITES:BOOL=1 ^
      -DINSTALL_PREREQUISITES:BOOL=1 ^
      "%~dp0\.."

if ERRORLEVEL 1 (
  echo ERROR: Configure failed
  exit /b 1
)

REM Build the library and tools
cmake --build . --config %CMAKE_CONFIG%

if ERRORLEVEL 1 (
  echo ERROR: Build failed
  exit /b 1
)

popd
@endlocal
