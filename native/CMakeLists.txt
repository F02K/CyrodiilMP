cmake_minimum_required(VERSION 3.22)
project(CyrodiilMPNative)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(CYRODIILMP_BUILD_UE4SS_GAMEHOST "Build UE4SS C++ GameHost mod" OFF)

add_subdirectory(CyrodiilMP.GameClient)
add_subdirectory(CyrodiilMP.Bootstrap)
add_subdirectory(CyrodiilMP.Launcher)

if(NOT CYRODIILMP_BUILD_UE4SS_GAMEHOST)
    message(STATUS "Skipping UE4SS GameHost. Set CYRODIILMP_BUILD_UE4SS_GAMEHOST=ON to build it.")
    return()
endif()

if(DEFINED ENV{UE4SS_ROOT})
    file(TO_CMAKE_PATH "$ENV{UE4SS_ROOT}" UE4SS_ROOT)
else()
    set(UE4SS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/RE-UE4SS")
endif()

if(NOT EXISTS "${UE4SS_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR
        "RE-UE4SS submodule not found at ${UE4SS_ROOT}.\n"
        "Either pass -Ue4ssRoot to scripts/build-native.ps1 or set UE4SS_ROOT.\n"
        "Run: git submodule add https://github.com/UE4SS-RE/RE-UE4SS vendor/RE-UE4SS\n"
        "Then: git submodule update --init --recursive")
endif()

add_subdirectory("${UE4SS_ROOT}" RE-UE4SS)
add_subdirectory(CyrodiilMP.GameHost)
