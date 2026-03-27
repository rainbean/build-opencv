#!/bin/bash
# Benchmark variant: builds OpenCV with OpenBLAS instead of intel-mkl.
# Outputs to dist/ (same as build.sh) so build-test.sh can be used unchanged.
# Usage: bash scripts/build-openblas.sh
#
# Benchmark workflow:
#   1. bash scripts/build.sh && bash scripts/build-test.sh      # MKL numbers
#   2. bash scripts/build-openblas.sh && bash scripts/build-test.sh  # OpenBLAS numbers
#   Compare [BENCH] output to decide x64 BLAS backend (see issue #5).

# install required 3rd party libraries
if [ ! -d "./vcpkg/installed/x64-linux/lib" ]
then
    echo "::group::Install vcpkg libraries ..."
    export VCPKG_DEFAULT_HOST_TRIPLET=x64-linux
    export VCPKG_DEFAULT_TRIPLET=x64-linux
    ./vcpkg/bootstrap-vcpkg.sh
    echo "::endgroup::"
fi

echo "::group::Install vcpkg libraries (openblas) ..."
export VCPKG_DEFAULT_HOST_TRIPLET=x64-linux
export VCPKG_DEFAULT_TRIPLET=x64-linux
./vcpkg/vcpkg install openblas tbb libjpeg-turbo --clean-after-build
echo "::endgroup::"

# Build opencv
echo "::group::Configure CMake and Build ..."
DIST_PATH="$PWD/dist"
cmake -Bbuild-openblas \
      -Wno-dev \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$DIST_PATH" \
      -DCMAKE_TOOLCHAIN_FILE="$PWD/vcpkg/scripts/buildsystems/vcpkg.cmake" \
      -DWITH_TBB=ON \
      -DWITH_MKL=OFF \
      -DWITH_OPENBLAS=ON \
      -DWITH_OPENGL=OFF \
      -DWITH_VA=OFF \
      -DBUILD_TIFF=OFF \
      -DWITH_TIFF=OFF \
      -DBUILD_PNG=ON \
      -DBUILD_JPEG=OFF \
      -DWITH_JPEG=ON \
      -DBUILD_WEBP=ON \
      -DBUILD_OPENJPEG=OFF \
      -DWITH_OPENJPEG=OFF \
      -DWITH_AVIF=OFF \
      -DWITH_QT=OFF \
      -DWITH_OPENEXR=OFF \
      -DWITH_FFMPEG=OFF \
      -DBUILD_opencv_apps=OFF \
      -DBUILD_DOCS=OFF \
      -DBUILD_PACKAGE=OFF \
      -DBUILD_PERF_TESTS=OFF \
      -DBUILD_TESTS=OFF \
      -DBUILD_JAVA=OFF \
      -DBUILD_opencv_python2=OFF \
      -DBUILD_opencv_python3=OFF \
      -DCV_TRACE=OFF \
      -DCMAKE_BUILD_RPATH_USE_ORIGIN=TRUE \
      -DBUILD_LIST="imgcodecs,imgproc" \
      -DBUILD_opencv_highgui=OFF \
      -DBUILD_opencv_features2d=OFF \
      -DBUILD_opencv_calib3d=OFF \
      -DBUILD_opencv_world=ON \
      opencv
cmake --build build-openblas -j 4 -t install
echo "::endgroup::"

# Bundle OpenBLAS and its Fortran runtime if dynamically linked.
# With vcpkg x64-linux (static linkage + NOFORTRAN=ON) this is a no-op.
# On ARM64 with dynamic triplets or system OpenBLAS the libs will be present.
echo "::group::Bundle OpenBLAS ..."
OPENBLAS_SO=$(ldd "$DIST_PATH/lib/libopencv_world.so" 2>/dev/null | awk '/libopenblas/{print $3}' | head -1)
if [ -n "$OPENBLAS_SO" ]; then
    # Resolve the real file (not symlinks) and copy it, then recreate symlinks cleanly
    OPENBLAS_REAL=$(readlink -f "$OPENBLAS_SO")
    OPENBLAS_FILE=$(basename "$OPENBLAS_REAL")
    cp "$OPENBLAS_REAL" "$DIST_PATH/lib/"
    ln -sf "$OPENBLAS_FILE" "$DIST_PATH/lib/libopenblas.so.0"
    ln -sf "$OPENBLAS_FILE" "$DIST_PATH/lib/libopenblas.so"
    echo "Bundled $OPENBLAS_FILE"

    # libgfortran is a runtime dependency of OpenBLAS (Fortran LAPACK routines)
    GFORTRAN_SO=$(ldd "$OPENBLAS_REAL" 2>/dev/null | awk '/libgfortran/{print $3}' | head -1)
    if [ -n "$GFORTRAN_SO" ]; then
        GFORTRAN_REAL=$(readlink -f "$GFORTRAN_SO")
        GFORTRAN_FILE=$(basename "$GFORTRAN_REAL")
        cp "$GFORTRAN_REAL" "$DIST_PATH/lib/"
        ln -sf "$GFORTRAN_FILE" "$DIST_PATH/lib/libgfortran.so.5"
        echo "Bundled $GFORTRAN_FILE"
    fi
else
    echo "OpenBLAS statically linked — nothing to bundle"
fi
echo "::endgroup::"

# pack binary
echo "::group::Pack artifacts ..."
TARGET=${1:-'opencv-linux-openblas.tar.zst'}
tar "-I zstd -3 -T4 --long=27" -cf $TARGET \
    -C $DIST_PATH $(cd $DIST_PATH; echo *)
echo "::endgroup::"
