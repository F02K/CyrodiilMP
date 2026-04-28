cmake_minimum_required(VERSION 3.22)
project(CyrodiilMPNative)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# RE-UE4SS must be checked out as a git submodule at vendor/RE-UE4SS.
# Run: git submodule add https://github.com/UE4SS-RE/RE-UE4SS vendor/RE-UE4SS
# Then: git submodule update --init --recursive
set(UE4SS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/RE-UE4SS")
if(NOT EXISTS "${UE4SS_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR
        "RE-UE4SS submodule not found at ${UE4SS_ROOT}.\n"
        "Run: git submodule add https://github.com/UE4SS-RE/RE-UE4SS vendor/RE-UE4SS\n"
        "Then: git submodule update --init --recursive")
endif()

add_subdirectory("${UE4SS_ROOT}" RE-UE4SS)
add_subdirectory(CyrodiilMP.GameHost)
