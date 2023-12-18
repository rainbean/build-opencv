if (Test-Path build-test) {
    rm -r build-test
}
cmake -Bbuild-test -G "Visual Studio 17 2022" -A "x64" -Wno-dev test
cmake --build build-test --config Release

$env:Path += ";C:\Users\code\build-opencv\dist\x64\vc17\bin"
Measure-Command { .\build-test\Release\test test\cards.png }