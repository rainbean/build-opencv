if (Test-Path build-test) {
    rm -r build-test
}
cmake -Bbuild-test -G "Visual Studio 16 2019" -A "x64" -Wno-dev test
cmake --build build-test --config Release
