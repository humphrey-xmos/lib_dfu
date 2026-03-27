cmake_minimum_required(VERSION 3.21)

project(error_conditions_test)

# Force release mode so that all the DLLs are statically linked
set (CMAKE_BUILD_TYPE "Release" CACHE STRING "Only Release mode is allowed" FORCE)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY  ${CMAKE_CURRENT_LIST_DIR}/bin)

if(NOT TARGET suffix_verifier)
    include(../../../../host/libsuffix_verifier/libsuffix_verifier.cmake)
endif()

add_executable(error_conditions error_conditions.c)

if (CMAKE_C_COMPILER_ID STREQUAL "MSVC")
    target_compile_options(error_conditions PRIVATE /O2 /W4)
else()
    target_compile_options(error_conditions PRIVATE -g -O2 -Wall -Wextra -Wpedantic
                            -Wconversion
                            -Wdiv-by-zero
                            -Wfloat-equal
                            -Wsign-compare
                            -Wshadow)
endif()

target_link_libraries(error_conditions PRIVATE suffix_verifier)