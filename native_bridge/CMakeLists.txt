cmake_minimum_required(VERSION 3.24)
project(mhws_eatshit_native_bridge LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(REFRAMEWORK_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/../tools/REFramework-sdk"
    CACHE PATH "Path to a checkout of praydog/REFramework")

add_library(mhws_eatshit_native_bridge SHARED Item98Bridge.cpp)
target_include_directories(mhws_eatshit_native_bridge PRIVATE
    "${REFRAMEWORK_SDK_ROOT}/include"
)
target_compile_definitions(mhws_eatshit_native_bridge PRIVATE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)
set_target_properties(mhws_eatshit_native_bridge PROPERTIES
    OUTPUT_NAME "mhws_eatshit_native_bridge"
    PREFIX ""
)
