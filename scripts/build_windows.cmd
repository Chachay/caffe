@echo off
@setlocal EnableDelayedExpansion

if NOT DEFINED MSVC_VERSION set MSVC_VERSION=14
if NOT DEFINED WITH_CUDA set WITH_CUDA=1
if NOT DEFINED VCPKG_DIR set VCPKG_DIR=C:\tools\vcpkg\installed\x64-windows
if NOT DEFINED BUILD_PYTHON set BUILD_PYTHON=0
if NOT DEFINED CMAKE_CONFIG set CMAKE_CONFIG=Release
if NOT DEFINED USE_NCCL set USE_NCCL=0
if NOT DEFINED USE_PREBUILD_VCPKG set USE_PREBUILD_VCPKG=0
if NOT DEFINED RUN_INSTALL set RUN_INSTALL=1
if NOT DEFINED CUDA_VER set CUDA_VER=8
if "%WITH_CUDA%"=="1" (
  if NOT DEFINED CPU_ONLY set CPU_ONLY=0
) else (
  if NOT DEFINED CPU_ONLY set CPU_ONLY=1
)

SET VCPKG_CMAKE=c:/tools/vcpkg/scripts/buildsystems/vcpkg.cmake

REM Dynamic Library
SET VCPKG_PBUILD_URI=https://www.dropbox.com/s/gzlvf6t6pebz2r7/vcpkg-export-20180618-223846.zip?dl=1
SET VCPKG_PBUILD_NAME=vcpkg-export-20180618-223846
SET VCPKG_TRIPLET=x64-windows

REM PATH TO FIND HDF5
SET HDF5_ROOT=C:\tools\%VCPKG_PBUILD_NAME%\installed\%VCPKG_TRIPLET%
SET HDF5_ROOT_DIR_HINT=C:\tools\%VCPKG_PBUILD_NAME%\installed\%VCPKG_TRIPLET%\share\hdf5

REM TODO: move environment setup into appveyor.yml or seperated script
if DEFINED APPVEYOR (
    echo Setting Appveryor Default
    if !PYTHON_VERSION! EQU 2 (
        set CONDA_ROOT=C:\Miniconda-x64
    )
    set PATH=!CONDA_ROOT!;!CONDA_ROOT!\Scripts;!CONDA_ROOT!\Library\bin;!PATH!
    python --version
    conda config --add channels conda-forge
    conda install --yes cmake numpy==1.10.4 scipy six scikit-image pyyaml graphviz
    if ERRORLEVEL 1  (
      echo ERROR: Conda update or install failed
      exit /b 1
    )
    REM Because of VCPKG's protobuf version as of 8th July 2018, protobuf should be later than some certain version to import pycaffe(protobuf 3.6.0 seems fine)
    REM pip install protobuf==3.1.0 pydotplus==2.0.2
    pip install protobuf==3.6.0 pydotplus==2.0.2
    if ERRORLEVEL 1  (
      echo ERROR: PIP update or install failed
      exit /b 1
    )
    echo ---------------------------------------
    echo VCPKG
    echo ---------------------------------------
    if !USE_PREBUILD_VCPKG! == 1 (
        echo Downloding prebuild VCPKG
        appveyor DownloadFile !VCPKG_PBUILD_URI! -FileName pvcpkg.zip
        7z x pvcpkg.zip -oc:\tools

        set VCPKG_CMAKE=c:\tools\!VCPKG_PBUILD_NAME!\scripts\buildsystems\vcpkg.cmake
        xcopy c:\tools\!VCPKG_PBUILD_NAME!\installed c:\tools\vcpkg\installed /S /E /I /Y /Q
        dir c:\tools\vcpkg\installed\!VCPKG_TRIPLET!
    ) else (
        vcpkg install glog gflags lmdb leveldb snappy protobuf hdf5 opencv openblas zlib libjpeg-turbo ^
                    boost-system boost-thread boost-filesystem boost-regex boost-python ^
                    --triplet !VCPKG_TRIPLET!
                    REM boost:x64-windows
    )
    if ERRORLEVEL 1  (
      echo ERROR: vcpkg update or install failed
      exit /b 1
    )
    if !WITH_CUDA! == 1 (
        if !CUDA_VER! == 8 (
            echo ---------------------------------------
            echo Install CUDA Toolkit 8.0 on appveyor
            echo ---------------------------------------
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
            appveyor DownloadFile http://developer.download.nvidia.com/compute/redist/cudnn/v7.0.5/cudnn-8.0-windows10-x64-v7.zip -FileName cudnn-8.0-windows-x64-v7.zip

            7z x cudnn-8.0-windows-x64-v7.zip -ocudnn

            copy cudnn\cuda\bin\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\bin"
            copy cudnn\cuda\lib\x64\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\lib\x64"
            copy cudnn\cuda\include\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\include"

            set PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\bin;!PATH!
            set CUDA_PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0
            set CUDA_PATH_V8_0=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0
        ) else if !CUDA_VER!==9 (
            echo ---------------------------------------
            echo Install CUDA Toolkit 9.0 on appveyor
            echo ---------------------------------------
            echo Downloading CUDA toolkit 9 ...
            appveyor DownloadFile  https://developer.nvidia.com/compute/cuda/9.1/Prod/local_installers/cuda_9.1.85_win10 -FileName setup.exe
            echo Installing CUDA toolkit 9 ...
            setup.exe -s compiler_9.1 ^
                                    cublas_9.1 ^
                                    cublas_dev_9.1 ^
                                    cudart_9.1 ^
                                    curand_9.1 ^
                                    curand_dev_9.1 ^
                                    nvml_dev_9.1

            if NOT EXIST "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.1\bin\cudart64_91.dll" (
                    echo "Failed to install CUDA"
                exit /B 1
            )
            echo Downloading cuDNN
            appveyor DownloadFile http://developer.download.nvidia.com/compute/redist/cudnn/v7.0.5/cudnn-9.1-windows10-x64-v7.zip -FileName cudnn-9.0-windows-x64-v7.zip

            7z x cudnn-9.1-windows-x64-v7.zip -ocudnn

            copy cudnn\cuda\bin\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.1\bin"
            copy cudnn\cuda\lib\x64\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.1\lib\x64"
            copy cudnn\cuda\include\*.* "!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.1\include"

            set PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.1\bin;!PATH!
            set CUDA_PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.1
            set CUDA_PATH_V9_1=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.1
        )
        nvcc -V
        cd "!APPVEYOR_BUILD_FOLDER!"
        REM ---------------------------------------
        set RUN_TESTS=0
    )
    if "%CMAKE_CONFIG%" == "Debug" (
        echo Disabling tests on appveyor with config == %CMAKE_CONFIG%
        set RUN_TESTS=0
    )
) else (
    if !WITH_CUDA! == 1 (
        if !CUDA_VER! == 8 (
            set PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0\bin;!PATH!
            set CUDA_PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0
            set CUDA_PATH_V8_0=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v8.0
        ) else if !CUDA_VER! == 9 (
            set PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.0\bin;!PATH!
            set CUDA_PATH=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.0
            set CUDA_PATH_V9_0=!ProgramFiles!\NVIDIA GPU Computing Toolkit\CUDA\v9.0
        )
        set RUN_TESTS=0
    )
)
REM Echo Path to check it
echo ------------------------------------
echo PATH=%PATH%

if %WITH_CUDA% == 1 (
    echo --------DIR:CUDA INCLUDE------------
    dir "!CUDA_PATH!\include"
    echo --------DIR:CUDA LIB----------------
    dir "!CUDA_PATH!\lib\x64"
    echo ------------------------------------
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

echo -------------------------------------------------
echo CMAKE Configure
echo -------------------------------------------------

cmake -G"%CMAKE_GENERATOR%" ^
      -DCMAKE_TOOLCHAIN_FILE=%VCPKG_CMAKE% ^
      -DVCPKG_TARGET_TRIPLET=%VCPKG_TRIPLET% ^
      -DBLAS=Open ^
      -DUSE_NCCL:BOOL=%USE_NCCL% ^
      -DCPU_ONLY:BOOL=%CPU_ONLY% ^
      -DCMAKE_BUILD_TYPE=%CMAKE_CONFIG% ^
      "%~dp0\.."

echo --------------CMakeOutput.log---------------------
cat "C:/project/caffe/build/CMakeFiles/CMakeOutput.log"
echo --------------CMakeError.log---------------------
cat "C:/project/caffe/build/CMakeFiles/CMakeError.log"

if ERRORLEVEL 1 (
  echo -----------------------------------------------
  echo ERROR: Configure failed
  echo -----------------------------------------------
  exit /b 1
)

echo -------------------------------------------------
echo CMAKE Build
echo -------------------------------------------------
REM Build the library and tools
cmake --build . --config %CMAKE_CONFIG%

if ERRORLEVEL 1 (
  echo ERROR: Build failed
  exit /b 1
)
echo -------------------------------------------------
echo CMAKE Install
echo -------------------------------------------------
if %RUN_INSTALL% EQU 1 (
    cmake --build . --target install --config %CMAKE_CONFIG%
    move .\install\python\caffe\_caffe.dll .\install\python\caffe\_caffe.pyd
    xcopy .\bin\!CMAKE_CONFIG! .\install\python\caffe /Y /F
    xcopy .\bin\!CMAKE_CONFIG! .\install\bin /Y /F
)
popd
@endlocal
