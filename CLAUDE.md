# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repo builds optimized OpenCV binaries for Linux (x64) and Windows (x64) using vcpkg for dependency management. Outputs are distributed as compressed archives to AWS S3 via GitHub Actions, triggered by git tags.

Current versions: OpenCV 4.11.0, vcpkg 2025.04.09

## Submodules

```bash
git submodule update --init --recursive
```

Both `opencv/` and `vcpkg/` are git submodules pinned to specific versions.

## Build Commands

### Linux
```bash
bash scripts/build.sh
```

### Windows
```powershell
.\scripts\build.ps1
```

### Test Build (Linux)
```bash
bash scripts/build-test.sh
```

### Test Build (Windows)
```powershell
.\scripts\build-test.ps1
```

### Generate Patch File
```bash
bash scripts/create-patch.sh
```

## Deploying / Releasing

Builds are triggered by pushing a git tag:
```bash
git tag <version>
git push origin <version>
```

GitHub Actions (`.github/workflows/build.yml`) runs matrix builds on Ubuntu 22.04 and Windows 2022, uploading artifacts to S3 using AWS IAM role credentials stored in GitHub secrets (`aws_iam_role`, `aws_s3_bucket`).

## Architecture

### Build System
- `scripts/build.sh` / `scripts/build.ps1`: Main build scripts. Install vcpkg dependencies (intel-mkl, tbb, libjpeg-turbo), configure CMake, build OpenCV, and pack the `dist/` directory.
- Output: `dist/` directory → `opencv-linux-{tag}.tar.zst` (Linux) or `opencv-win64-{tag}.7z` (Windows)

### OpenCV Modules Built
Only a subset of OpenCV is compiled: `imgcodecs`, `imgproc`. FFmpeg, Qt, Python bindings, Java, tests, and docs are all disabled.

### Dependencies (via vcpkg)
- OpenBLAS (Linux; benchmarked identical to intel-mkl for this pipeline)
- Intel MKL (Windows only)
- TBB (threading)
- Image codecs: libpng, libjpeg-turbo, libwebp

### Patches
- `patch/x64-windows.cmake`: vcpkg triplet for Windows (static CRT/libs, dynamic TBB, release-only)
- `patch/opencv_libavif.patch`: Patches OpenCV CMake to add AOM/YUV dependencies (AVIF support is disabled in current builds but patch is maintained)

### Test Application
`test/watershed.cc` is the validation binary. It runs the watershed segmentation algorithm on `test/cards.png` and asserts exactly 14 contours are detected. Uses OpenMP for parallelization across 100 iterations.
