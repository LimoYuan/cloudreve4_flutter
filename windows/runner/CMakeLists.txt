cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "floating_upload_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "gdiplus.lib" "shlwapi.lib" "ole32.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Copy Rust sync_core.dll to output directory after build
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_BINARY_DIR}/rust_target/$<IF:$<CONFIG:Release>,release,debug>/sync_core.dll"
        "$<TARGET_FILE_DIR:${BINARY_NAME}>"
    COMMENT "Copying sync_core.dll to output directory"
)

# === VC Runtime DLLs ===
# Bundle vcruntime140.dll / msvcp140.dll etc. next to the executable so the app
# runs on machines without VC Redistributable installed.
# Source: MSVC toolchain dir (cl.exe's dir) — version strictly matches the
# toolchain used at compile time, avoiding System32 version drift.
# Release/Profile only: Debug runs on dev machine with VS installed.
# concrt140.dll excluded: MSVC 14.31+ moved it out of toolchain bin dir, and
# Flutter Windows apps don't use ConcRT.
# POST_BUILD only (no install()): INSTALL_BUNDLE_LIB_DIR is defined in parent
# CMakeLists.txt after add_subdirectory("runner"), so it's empty here.
# POST_BUILD copies to $<TARGET_FILE_DIR:${BINARY_NAME}> which is the final
# Flutter output dir.
if(MSVC)
    get_filename_component(CXX_COMPILER_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
    set(VC_RUNTIME_DLLS
        vcruntime140.dll
        vcruntime140_1.dll
        msvcp140.dll
    )
    set(_VC_REL_CONFIGS "$<OR:$<CONFIG:Release>,$<CONFIG:Profile>>")
    foreach(dll ${VC_RUNTIME_DLLS})
        set(SRC_DLL "${CXX_COMPILER_DIR}/${dll}")
        if(EXISTS "${SRC_DLL}")
            add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
                COMMAND $<${_VC_REL_CONFIGS}:${CMAKE_COMMAND}>
                        $<${_VC_REL_CONFIGS}:-E>
                        $<${_VC_REL_CONFIGS}:copy_if_different>
                        $<${_VC_REL_CONFIGS}:"${SRC_DLL}">
                        $<${_VC_REL_CONFIGS}:"$<TARGET_FILE_DIR:${BINARY_NAME}>">
                COMMENT "Copy ${dll} to output directory (Release/Profile only)"
            )
        else()
            message(WARNING "VC Runtime DLL not found: ${SRC_DLL}")
        endif()
    endforeach()
    unset(_VC_REL_CONFIGS)
endif()
