#!/bin/bash

git submodule --quiet foreach --recursive 'export NAME="${PWD##*/}"; git --no-pager diff --src-prefix="a/${NAME}/" --dst-prefix="b/${NAME}/"' > opencv.patch