cmake_minimum_required(VERSION 3.22)
set(TARGET CyrodiilMP.GameClient)

add_library(${TARGET} SHARED
    src/DllMain.cpp
    src/CommandWatcher.cpp
    src/GameClient.cpp
    src/Log.cpp
    src/NetworkClient.cpp
)

target_include_directories(${TARGET}
    PUBLIC include
    PRIVATE src)

target_link_libraries(${TARGET} PRIVATE ws2_32)

add_executable(CyrodiilMP.GameClient.Host
    tools/GameClientHost.cpp
)

target_link_libraries(CyrodiilMP.GameClient.Host PRIVATE ${TARGET})

set(GAMECLIENT_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../artifacts/native/$<CONFIG>/GameClient")

set_target_properties(${TARGET} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${GAMECLIENT_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${GAMECLIENT_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${GAMECLIENT_OUTPUT_DIR}"
)

set_target_properties(CyrodiilMP.GameClient.Host PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${GAMECLIENT_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${GAMECLIENT_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${GAMECLIENT_OUTPUT_DIR}"
)

if(MSVC)
    target_compile_options(${TARGET} PRIVATE /W4 /permissive-)
    target_compile_options(CyrodiilMP.GameClient.Host PRIVATE /W4 /permissive-)
endif()
