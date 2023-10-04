#!/bin/bash

# install required 3rd party libraries

if [ ! -d "./vcpkg/installed/x64-linux-release/lib" ]
then
    echo "::group::Install vcpkg libraries ..."
    # specify triplet
    export VCPKG_DEFAULT_HOST_TRIPLET=x64-linux-release
    export VCPKG_DEFAULT_TRIPLET=x64-linux-release
    ./vcpkg/bootstrap-vcpkg.sh
    ./vcpkg/vcpkg install intel-mkl libavif tbb --clean-after-build
    # workaround: opencv failed to detect release triplet
    ln -s $PWD/vcpkg/installed/x64-linux-release vcpkg/installed/x64-linux
    echo "::endgroup::"
fi


# Apply patch to submodules
if [ ! -f "./opencv/cmake/OpenCVFindAOM.cmake" ]
then
    echo "::group::Patch libavif ..."
    git apply --ignore-space-change --ignore-whitespace opencv_libavif.patch
    echo "::endgroup::"
fi

# Build opencv
echo "::group::Configure CMake and Build ..."
DIST_PATH="$PWD/dist"
cmake -Bbuild \
      -Wno-dev \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="${DIST_PATH}" \
      -DCMAKE_TOOLCHAIN_FILE="$PWD/vcpkg/scripts/buildsystems/vcpkg.cmake" \
      -DOPENCV_EXTRA_MODULES_PATH="$PWD/opencv_contrib/modules" \
      -DWITH_TBB=ON \
      -DWITH_CUDA=ON \
      -DWITH_OPENGL=ON \
      -DBUILD_TIFF=ON \
      -DBUILD_PNG=ON \
      -DBUILD_JPEG=ON \
      -DBUILD_WEBP=ON \
      -DBUILD_OPENJPEG=ON \
      -DWITH_AVIF=ON \
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
      -DBUILD_LIST="imgcodecs,imgproc,highgui,cudaimgproc,cudev" \
      -DBUILD_opencv_world=ON \
      opencv
cmake --build build -j 4 -t install
echo "::endgroup::"

# pack binary
echo "::group::Pack artifacts ..."

cp -a /usr/local/cuda/lib64/libnppc.so* $DIST_PATH/lib
cp -a /usr/local/cuda/lib64/libnppial.so* $DIST_PATH/lib
cp -a /usr/local/cuda/lib64/libnppicc.so* $DIST_PATH/lib
cp -a /usr/local/cuda/lib64/libnppidei.so* $DIST_PATH/lib
cp -a /usr/local/cuda/lib64/libnppist.so* $DIST_PATH/lib

TARGET=${1:-'opencv-linux.tar.zst'}
tar "-I zstd -3 -T4 --long=27" -cf $TARGET \
    -C $DIST_PATH $(cd $DIST_PATH; echo *)
echo "::endgroup::"
