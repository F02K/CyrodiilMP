cmake_minimum_required(VERSION 3.22)
set(TARGET CyrodiilMP.Launcher)

add_executable(${TARGET}
    src/main.cpp
)

set(LAUNCHER_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../artifacts/native/$<CONFIG>/Standalone")

set_target_properties(${TARGET} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${LAUNCHER_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${LAUNCHER_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${LAUNCHER_OUTPUT_DIR}"
)

if(MSVC)
    target_compile_options(${TARGET} PRIVATE /W4 /permissive-)
endif()
