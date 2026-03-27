cmake_minimum_required(VERSION 3.21)

project(basic_verifier_test)

# Force release mode so that all the DLLs are statically linked
set (CMAKE_BUILD_TYPE "Release" CACHE STRING "Only Release mode is allowed" FORCE)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY  ${CMAKE_CURRENT_LIST_DIR}/bin)

if(NOT TARGET suffix_verifier)
    include(../../../../host/libsuffix_verifier/libsuffix_verifier.cmake)
endif()

add_executable(basic_verifier basic_verifier.c)

if (CMAKE_C_COMPILER_ID STREQUAL "MSVC")
    target_compile_options(basic_verifier PRIVATE /O2 /W4)
else()
    target_compile_options(basic_verifier PRIVATE -g -O2 -Wall -Wextra -Wpedantic
                                -Wconversion
                                -Wdiv-by-zero
                                -Wfloat-equal
                                -Wsign-compare
                                -Wshadow)
endif()

target_link_libraries(basic_verifier PRIVATE suffix_verifier)
