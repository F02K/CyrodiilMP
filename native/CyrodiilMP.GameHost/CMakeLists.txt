cmake_minimum_required(VERSION 3.22)
set(TARGET CyrodiilMP.GameHost)
project(${TARGET})

add_library(${TARGET} SHARED
    dllmain.cpp
    src/GameHostMod.cpp
    src/ButtonInjector.cpp
    src/HookManager.cpp
    src/BridgeLauncher.cpp
    src/ScriptingHost.cpp
    src/UiRuntime.cpp
)

target_include_directories(${TARGET} PRIVATE include)

# UE4SS target is provided by the RE-UE4SS subdirectory in the parent CMakeLists.
target_link_libraries(${TARGET} PRIVATE UE4SS)

# Place the output DLL directly into the UE4SS mod folder so that
# install-cyrodiilmp-ue4ss-mods only needs to copy from here.
set(MOD_OUTPUT_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../../game-plugin/UE4SS/Mods/CyrodiilMP.GameHost/dlls")

set_target_properties(${TARGET} PROPERTIES
    OUTPUT_NAME "main"
    RUNTIME_OUTPUT_DIRECTORY           "${MOD_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG     "${MOD_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE   "${MOD_OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${MOD_OUTPUT_DIR}"
)

# Suppress the default lib export; UE4SS mods don't use it.
if(MSVC)
    target_compile_options(${TARGET} PRIVATE /W3)
    # Use the same runtime as UE4SS itself (multi-threaded DLL).
    set_property(TARGET ${TARGET} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
endif()
