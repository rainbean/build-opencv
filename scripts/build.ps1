# param must be in the begin of PowerShell Script
param ($TARGET = "opencv-win64.7z")

# Set path
$env:Path = "C:\Program Files\CMake\bin\;C:\Program Files\NASM\;$env:Path"

# install 7zip ZSTD plugin
if (!(choco list --lo --r -e 7zip-zstd)) {
    Write-Output "::group::Install 7Z-ZSTD plugin ..."
    choco install -y 7zip-zstd | Out-Null
    Write-Output "::endgroup::"
}

if (!(Get-Command nasm -errorAction SilentlyContinue)) {
    Write-Output "::group::Install nasm assembler ..."
    choco install -y nasm | Out-Null
    Write-Output "::endgroup::"
}

if (!(Get-Command cmake -errorAction SilentlyContinue)) {
    Write-Output "::group::Install cmake ..."
    choco install -y cmake | Out-Null
    Write-Output "::endgroup::"
}

# install required 3rd party libraries
if (!(Test-Path .\vcpkg\installed\x64-windows)) {
    Write-Output "::group::Install vcpkg libraries ..."
    # specify triplet
    $env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows"
    $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    # refer to https://github.com/facebookresearch/faiss/issues/2641
    # replace MKL interface to LP
    $MKL_CMAKE = ".\vcpkg\ports\intel-mkl\portfile.cmake"
    (Get-content $MKL_CMAKE) | Foreach-Object {
        $_ -replace "ilp64", "lp64" -replace "intel_thread", "sequential"
    } | Set-Content $MKL_CMAKE
    # install required libraries
    .\vcpkg\bootstrap-vcpkg.bat
    .\vcpkg\vcpkg install intel-mkl eigen3 tbb --clean-after-build
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
      -DWITH_OPENGL=ON `
      -DWITH_VA=OFF `
      -DBUILD_TIFF=ON `
      -DBUILD_PNG=ON `
      -DBUILD_JPEG=ON `
      -DBUILD_WEBP=ON `
      -DBUILD_OPENJPEG=ON `
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
      -DBUILD_LIST="imgcodecs,imgproc,highgui" `
      -DBUILD_opencv_world=ON `
      opencv
cmake --build build -j 4 -t install --config Release
Write-Output "::endgroup::"

# pack binary
Write-Output "::group::Pack artifacts ..."
# copy deps binary
Copy-Item vcpkg\installed\x64-windows\bin\tbb12.dll $DIST_PATH\x64\vc17\bin\
Copy-Item vcpkg\installed\x64-windows\bin\mkl_sequential.2.dll $DIST_PATH\x64\vc17\bin\
# pack binary
Push-Location $DIST_PATH
7z a -m0=bcj -m1=zstd ..\$TARGET * | Out-Null
Pop-Location
Write-Output "::endgroup::"
