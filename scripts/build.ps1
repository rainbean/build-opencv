# param must be in the begin of PowerShell Script
param ($TARGET = "opencv-win64.7z")

# Set path
$env:Path = "C:\Program Files\CMake\bin\;C:\Program Files\NASM\;$env:Path"

if (!(Get-Command cmake -errorAction SilentlyContinue)) {
    Write-Output "::group::Install cmake ..."
    winget install cmake | Out-Null
    Write-Output "::endgroup::"
}

# install required 3rd party libraries
if (!(Test-Path .\vcpkg\installed\x64-windows)) {
    Write-Output "::group::Install vcpkg libraries ..."
    .\vcpkg\bootstrap-vcpkg.bat
    .\vcpkg\vcpkg install openblas tbb libjpeg-turbo --triplet x64-windows --clean-after-build
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
      -G "Visual Studio 17 2022" `
      -A x64 `
      -Wno-dev `
      -DCMAKE_INSTALL_PREFIX="${DIST_PATH}" `
      -DCMAKE_TOOLCHAIN_FILE="${PWD}/vcpkg/scripts/buildsystems/vcpkg.cmake" `
      -DWITH_TBB=ON `
      -DWITH_MKL=OFF `
      -DWITH_OPENBLAS=ON `
      -DWITH_LAPACK=OFF `
      -DWITH_OPENGL=OFF `
      -DWITH_VA=OFF `
      -DBUILD_TIFF=OFF `
      -DWITH_TIFF=OFF `
      -DBUILD_PNG=ON `
      -DBUILD_JPEG=OFF `
      -DWITH_JPEG=ON `
      -DBUILD_WEBP=ON `
      -DBUILD_OPENJPEG=OFF `
      -DWITH_OPENJPEG=OFF `
      -DWITH_AVIF=OFF `
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
      -DBUILD_LIST="imgcodecs,imgproc" `
      -DBUILD_opencv_highgui=OFF `
      -DBUILD_opencv_features2d=OFF `
      -DBUILD_opencv_calib3d=OFF `
      -DBUILD_opencv_world=ON `
      opencv
cmake --build build -j 4 -t install --config Release
Write-Output "::endgroup::"

# pack binary
Write-Output "::group::Pack artifacts ..."
# copy deps binary
Copy-Item vcpkg\installed\x64-windows\bin\tbb12.dll $DIST_PATH\x64\vc17\bin\
Copy-Item vcpkg\installed\x64-windows\bin\openblas.dll $DIST_PATH\x64\vc17\bin\
Copy-Item vcpkg\installed\x64-windows\bin\jpeg62.dll $DIST_PATH\x64\vc17\bin\
# pack binary (standard 7z LZMA2, no plugin required)
Push-Location $DIST_PATH
7z a -mx=3 ..\$TARGET * | Out-Null
Pop-Location
Write-Output "::endgroup::"
