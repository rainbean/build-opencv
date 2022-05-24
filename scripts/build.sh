# install required 3rd party libraries
echo "Install vcpkg libraries"
./vcpkg/bootstrap-vcpkg.sh
./vcpkg/vcpkg install eigen3 tbb --triplet x64-linux --clean-after-build
# linux vcpkg openblas dependencies is missing https://github.com/microsoft/vcpkg/issues/23333

# Build opencv
cd opencv
cmake -Bbuild -H. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="../dist" \
      -DCMAKE_TOOLCHAIN_FILE="../vcpkg/scripts/buildsystems/vcpkg.cmake" \
      -DWITH_EIGEN=ON -DWITH_TBB=ON -DWITH_OPENGL=ON -DBUILD_TIFF=ON \
      -DWITH_QT=OFF -DWITH_FFMPEG=OFF \
      -DBUILD_opencv_apps=OFF -DBUILD_DOCS=OFF -DBUILD_PACKAGE=OFF \
      -DBUILD_PERF_TESTS=OFF -DBUILD_TESTS=OFF -DBUILD_JAVA=OFF \
      -DBUILD_opencv_python2=OFF -DBUILD_opencv_python3=OFF \
      -DBUILD_LIST=imgcodecs,imgproc,highgui \
      -DBUILD_opencv_world=ON

# Build
cd build
make -j4
make install

# pack
cd ../../dist
export XZ_DEFAULTS="-T 0"
tar Jcf ../opencv-linux.tar.xz *
