# Download and install OpenBLAS
wget https://github.com/xianyi/OpenBLAS/releases/download/v0.3.21/OpenBLAS-0.3.21.tar.gz -O OpenBLAS.tgz
tar xf OpenBLAS.tgz
cd OpenBLAS-0.3.21
make
make install PREFIX=../OpenBLAS
cd ..
export OpenBLAS_HOME="$PWD/OpenBLAS"

# install required 3rd party libraries
echo "Install vcpkg libraries"
./vcpkg/bootstrap-vcpkg.sh
./vcpkg/vcpkg install eigen3 tbb --triplet x64-linux --clean-after-build
# linux vcpkg openblas dependencies is missing https://github.com/microsoft/vcpkg/issues/23333

# Build opencv
cd opencv
cmake -Bbuild \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="../dist" \
      -DCMAKE_TOOLCHAIN_FILE="../vcpkg/scripts/buildsystems/vcpkg.cmake" \
      -DWITH_EIGEN=ON \
      -DWITH_TBB=ON \
      -DWITH_OPENGL=ON \
      -DBUILD_TIFF=ON \
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
      -DBUILD_opencv_world=ON

# Build
cd build
make -j4
make install

# pack
cd ../../dist
cp -aP ../OpenBLAS/lib/*.so* lib/
export XZ_DEFAULTS="-T 0"
tar Jcf ../opencv-linux.tar.xz *
