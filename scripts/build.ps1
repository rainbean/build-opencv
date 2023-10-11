# param must be in the begin of PowerShell Script
param ($TARGET = "opencv-win64.7z")

# Set path
$env:Path = "C:\Program Files\CMake\bin\;C:\Program Files\NASM\;C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\;C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.1\bin;$env:Path"

if (!(Get-Command nasm -errorAction SilentlyContinue)) {
    Write-Output "::group::Install nasm assembler ..."
    choco install -y nasm | Out-Null
    Write-Output "::endgroup::"
}

# install required 3rd party libraries
if (!(Test-Path .\vcpkg\installed\x64-windows)) {
    Write-Output "::group::Install vcpkg libraries ..."
    # replace MKL interface to LP
    $MKL_CMAKE = ".\vcpkg\ports\intel-mkl\portfile.cmake"
    (Get-content $MKL_CMAKE) | Foreach-Object {
        $_ -replace "ilp64", "lp64" -replace "dynamic", "static"
    } | Set-Content $MKL_CMAKE
    # specify triplet
    $env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows-release"
    $env:VCPKG_DEFAULT_TRIPLET = "x64-windows-release"
    .\vcpkg\bootstrap-vcpkg.bat
    .\vcpkg\vcpkg install intel-mkl libavif tbb --clean-after-build
    # workaround: opencv failed to detect release triplet
    New-Item -ItemType Junction -Path "$PWD/vcpkg/installed/x64-windows" -Target "$PWD/vcpkg/installed/x64-windows-release"
    Write-Output "::endgroup::"
}

# Apply patch to submodules
if (!(Test-Path .\opencv\cmake\OpenCVFindAOM.cmake)) {
    Write-Output "::group::Patch libavif ..."
    git apply --ignore-space-change --ignore-whitespace opencv_libavif.patch
    Write-Output "::endgroup::"
}

# Build opencv
Write-Output "::group::Configure CMake and Build ..."
if (Test-Path build) {
    rm -r build
}
if (Test-Path dist) {
    rm -r dist
}

$DIST_PATH = "${PWD}/dist"
cmake -Bbuild `
      -A x64 `
      -Wno-dev `
      -DCMAKE_INSTALL_PREFIX="${DIST_PATH}" `
      -DCMAKE_TOOLCHAIN_FILE="${PWD}/vcpkg/scripts/buildsystems/vcpkg.cmake" `
      -DWITH_TBB=ON `
      -DWITH_OPENGL=ON `
      -DBUILD_TIFF=ON `
      -DBUILD_PNG=ON `
      -DBUILD_JPEG=ON `
      -DBUILD_WEBP=ON `
      -DBUILD_OPENJPEG=ON `
      -DWITH_AVIF=ON `
      -DWITH_QT=OFF `
      -DWITH_OPENEXR=OFF `
      -DWITH_FFMPEG=OFF `
      -DBUILD_opencv_apps=OFF `
      -DBUILD_DOCS=OFF `
      -DBUILD_PACKAGE=OFF `
      -DBUILD_PERF_TESTS=OFF `
      -DBUILD_TESTS=OFF `
      -DBUILD_JAVA=OFF `
      -DBUILD_opencv_python2=OFF `
      -DBUILD_opencv_python3=OFF `
      -DCV_TRACE=OFF `
      -DCMAKE_BUILD_RPATH_USE_ORIGIN=TRUE `
      -DBUILD_LIST="imgcodecs,imgproc,highgui" `
      -DBUILD_opencv_world=ON `
      opencv
cmake --build build -j 4 -t install --config Release
Write-Output "::endgroup::"

# # define MKL path
# $MKL_PATH = "$PWD\vcpkg\installed\x64-windows-static\lib\intel64"
# $MKL_LIBRARIES = "${MKL_PATH}\mkl_intel_lp64.lib;${MKL_PATH}\mkl_intel_thread.lib;${MKL_PATH}\mkl_core.lib;${MKL_PATH}\libiomp5md.lib"
# $DIST_PATH = "$PWD\dist"

# # copy artifacts and change config
# cp $MKL_PATH\mkl_intel_lp64.lib $DIST_PATH\lib
# cp $MKL_PATH\mkl_intel_thread.lib $DIST_PATH\lib
# cp $MKL_PATH\mkl_core.lib $DIST_PATH\lib
# cp $MKL_PATH\libiomp5md.lib $DIST_PATH\lib
# cp $MKL_PATH\libiomp5md.lib $DIST_PATH\lib
# mkdir -p $DIST_PATH\bin
# cp $MKL_PATH\..\..\bin\libiomp5md.dll $DIST_PATH\bin

# pack binary
Write-Output "::group::Pack artifacts ..."
# pack binary
Push-Location $DIST_PATH
7z a -m0=bcj -m1=zstd ..\$TARGET * | Out-Null
Pop-Location
Write-Output "::endgroup::"
