#!/bin/bash

if [ -d build-test ]
then
    rm -fr build-test
fi
cmake -Bbuild-test -Wno-dev test
cmake --build build-test --config Release
time ./build-test/test test/cards.png