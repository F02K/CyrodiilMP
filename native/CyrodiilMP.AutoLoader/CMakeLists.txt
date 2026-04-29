cmake_minimum_required(VERSION 3.22)
set(TARGET CyrodiilMP.AutoLoader)

add_library(${TARGET} SHARED
    src/VersionProxy.cpp
    src/version_proxy.def
)

set(AUTOLOADER_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../artifacts/native/$<CONFIG>/AutoLoader")

set_target_properties(${TARGET} PROPERTIES
    OUTPUT_NAME "version"
    RUNTIME_OUTPUT_DIRECTORY "${AUTOLOADER_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${AUTOLOADER_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${AUTOLOADER_OUTPUT_DIR}"
)

if(MSVC)
    target_compile_options(${TARGET} PRIVATE /W4 /permissive-)
    target_link_options(${TARGET} PRIVATE "/DEF:${CMAKE_CURRENT_SOURCE_DIR}/src/version_proxy.def")
endif()
