cmake_minimum_required(VERSION 3.16) # Note older version to support Buster
project("suffix_generator")

# Force release mode so that all the DLLs are statically linked
set (CMAKE_BUILD_TYPE "Release" CACHE STRING "Only Release mode is allowed" FORCE)

set (INCLUDE_DIRS 
        "../api"
)

set (SOURCE_FILES
        src/dfu_suffix_generator.c
        src/crc.c
)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY  ${CMAKE_CURRENT_LIST_DIR}/bin)

set (SUFFIX_GEN dfu_suffix_generator)
add_executable(${SUFFIX_GEN} ${SOURCE_FILES})
target_link_libraries(${SUFFIX_GEN} )
target_include_directories(${SUFFIX_GEN} PRIVATE ${INCLUDE_DIRS})

if (CMAKE_C_COMPILER_ID STREQUAL "MSVC")
        target_compile_options(${SUFFIX_GEN} PUBLIC /O2 /W4)
else()
        target_compile_options(${SUFFIX_GEN} PUBLIC -g -O2 -Wall -Wextra -Wpedantic
                                -Wconversion
                                -Wdiv-by-zero
                                -Wfloat-equal
                                -Wsign-compare
                                -Wshadow)
endif()
