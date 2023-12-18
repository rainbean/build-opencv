cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

# append library search path
list(APPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../dist")

# define project
project(test LANGUAGES CXX)

# define required library
find_package(OpenCV REQUIRED)
find_package(OpenMP REQUIRED)

# specify platform config
if(MSVC)
    # Set Source and Executable character sets to UTF-8
    add_compile_options("$<$<C_COMPILER_ID:MSVC>:/utf-8>")
    add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
endif(MSVC)

if(UNIX OR MINGW)
    # surpress deprecated warning
    set(CMAKE_CXX_FLAGS "-Wno-error=deprecated-declarations -Wno-deprecated-declarations")

    # look for .so files in the current working directory first
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-rpath='$ORIGIN'")
endif()

# define deliverables
include_directories(test ${CUDA_INCLUDE_DIRS})

# irseg target
file(GLOB_RECURSE test_files
    "*.cc"
)
add_executable(test ${test_files})
if(MSVC)
    target_compile_options(test PRIVATE -openmp:llvm -openmp:experimental)
endif(MSVC)
set_property(TARGET test PROPERTY CXX_STANDARD 17)
target_link_libraries(
    test
    ${OpenCV_LIBS}
    OpenMP::OpenMP_CXX
)
