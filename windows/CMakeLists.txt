# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(cloudreve4_flutter LANGUAGES CXX)

# Workaround for MSVC 14.51+ and plugins using <experimental/coroutine>.
add_definitions(-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "cloudreve4_flutter")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# flutter_inappwebview_windows requires NuGet; help CMake find it
if(NOT DEFINED NUGET OR NUGET STREQUAL "NUGET-NOTFOUND")
  find_program(NUGET nuget PATHS
    "$ENV{USERPROFILE}\\.local\\bin"
    "$ENV{LOCALAPPDATA}\\Microsoft\\WinGet\\Links"
    "C:/ProgramData/chocolatey/bin"
    NO_DEFAULT_PATH
  )
  find_program(NUGET nuget)
  if(NUGET AND NOT NUGET STREQUAL "NUGET-NOTFOUND")
    message(STATUS "Found NuGet: ${NUGET}")
    set(NUGET "${NUGET}" CACHE FILEPATH "nuget executable" FORCE)
  endif()
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

if(MSVC)
    if(TARGET flutter_inappwebview_windows_plugin)
        # flutter_inappwebview 插件有很多 MSVC 警告, 屏蔽该插件不输出任何警告
        target_compile_options(flutter_inappwebview_windows_plugin PRIVATE /W0)
    endif()
endif()

# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
#if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
#  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
#endif()

set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# === Rust Sync Engine ===
find_program(CARGO_CMD cargo
    PATHS
        "$ENV{USERPROFILE}\\.cargo\\bin"
        "$ENV{HOME}\\.cargo\\bin"
        "$ENV{CARGO_HOME}\\bin"
    NO_DEFAULT_PATH
)
if(NOT CARGO_CMD)
    find_program(CARGO_CMD cargo)
endif()

if(NOT CARGO_CMD)
    message(WARNING "cargo not found, skipping Rust sync engine build")
else()
    set(SYNC_CORE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native")
    set(RUST_TARGET_DIR "${CMAKE_BINARY_DIR}/rust_target")

    # 1. 编译时间戳文件
    set(RUST_BUILD_STAMP "${CMAKE_CURRENT_BINARY_DIR}/sync_core_build.stamp")

    # 2. 核心修复
    # 不管是 Debug 还是 Release，我们都同时通知 Cargo 去检查这两个配置。
    # 这样没有任何动态变量，参数数量是死死固定的，Cargo 100% 不会报错。
    add_custom_command(
        OUTPUT "${RUST_BUILD_STAMP}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${RUST_TARGET_DIR}"

        # 无论如何，都去编译 Debug（供 flutter run 使用）
        COMMAND ${CARGO_CMD} build
            --manifest-path "${SYNC_CORE_DIR}/Cargo.toml"
            --target-dir "${RUST_TARGET_DIR}"
            --features sync-core/windows-cfapi

        # 无论如何，都去编译 Release（供 flutter build 使用）
        COMMAND ${CARGO_CMD} build --release
            --manifest-path "${SYNC_CORE_DIR}/Cargo.toml"
            --target-dir "${RUST_TARGET_DIR}"
            --features sync-core/windows-cfapi

        COMMAND ${CMAKE_COMMAND} -E touch "${RUST_BUILD_STAMP}"
        COMMENT "Building Rust sync engine (Debug & Release)..."
        VERBATIM
    )

    # 3. 让目标依赖时间戳
    add_custom_target(sync_core_build DEPENDS "${RUST_BUILD_STAMP}")
    add_dependencies(${BINARY_NAME} sync_core_build)

    # 4. 动态选择文件夹名称表达式（这个表达式只在安装阶段求值，安全可靠）
    set(CONFIG_DIR_EXPR "$<IF:$<OR:$<CONFIG:Release>,$<CONFIG:Profile>>,release,debug>")

    # 5. 动态选择 dll 路径进行安装复制
    install(FILES "${RUST_TARGET_DIR}/${CONFIG_DIR_EXPR}/sync_core.dll"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)
endif()