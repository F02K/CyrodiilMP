cmake_minimum_required(VERSION 3.22)
project(CyrodiilMPNative)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(CyrodiilMP.GameClient)
add_subdirectory(CyrodiilMP.Bootstrap)
add_subdirectory(CyrodiilMP.Launcher)
