cmake_minimum_required(VERSION 3.22)
set(TARGET CyrodiilMP.Bootstrap)

add_library(${TARGET} SHARED
    src/Bootstrap.cpp
    src/DebugConsole.cpp
    src/DllMain.cpp
    src/Log.cpp
    src/PatternScanner.cpp
    src/Settings.cpp
    src/UiRuntime.cpp
    src/UEBridge.cpp
    src/UEPatterns.cpp
)

target_include_directories(${TARGET}
    PRIVATE
        src
        "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/NirnLabUIPlatformOR/src/UIPlatform"
)

set(BOOTSTRAP_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../artifacts/native/$<CONFIG>/Standalone")

set_target_properties(${TARGET} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${BOOTSTRAP_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${BOOTSTRAP_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${BOOTSTRAP_OUTPUT_DIR}"
)

if(MSVC)
    target_compile_options(${TARGET} PRIVATE /W4 /permissive-)
endif()
