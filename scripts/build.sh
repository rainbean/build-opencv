#!/bin/bash

# install required 3rd party libraries
if [ ! -d "./vcpkg/installed/x64-linux/lib" ]
then
    echo "::group::Install vcpkg libraries ..."
    # specify triplet
    export VCPKG_DEFAULT_HOST_TRIPLET=x64-linux
    export VCPKG_DEFAULT_TRIPLET=x64-linux
    ./vcpkg/bootstrap-vcpkg.sh
    ./vcpkg/vcpkg install intel-mkl eigen3 tbb --clean-after-build
    echo "::endgroup::"
fi

# Build opencv
echo "::group::Configure CMake and Build ..."
DIST_PATH="$PWD/dist"
cmake -Bbuild \
      -Wno-dev \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$DIST_PATH" \
      -DCMAKE_TOOLCHAIN_FILE="$PWD/vcpkg/scripts/buildsystems/vcpkg.cmake" \
      -DWITH_TBB=ON \
      -DWITH_OPENGL=ON \
      -DWITH_VA=OFF \
      -DBUILD_TIFF=ON \
      -DBUILD_PNG=ON \
      -DBUILD_JPEG=ON \
      -DBUILD_WEBP=ON \
      -DBUILD_OPENJPEG=ON \
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
      -DBUILD_LIST="imgcodecs,imgproc,highgui" \
      -DBUILD_opencv_world=ON \
      opencv
cmake --build build -j 4 -t install
echo "::endgroup::"

# pack binary
echo "::group::Pack artifacts ..."
cp -a $OpenBLAS_HOME/lib/*.so* $DIST_PATH/lib
TARGET=${1:-'opencv-linux.tar.zst'}
tar "-I zstd -3 -T4 --long=27" -cf $TARGET \
    -C $DIST_PATH $(cd $DIST_PATH; echo *)
echo "::endgroup::"
