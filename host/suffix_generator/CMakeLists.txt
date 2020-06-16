cmake_minimum_required(VERSION 3.7)

# Force release mode so that all the DLLs are statically linked
set (CMAKE_BUILD_TYPE "Release" CACHE STRING "Only Release mode is allowed" FORCE)

set (DEFINES _GNU_SOURCE HOST_APP)

set (INCLUDE_DIRS 
        "../../lib_dfu/api"
)

set (SOURCE_FILES
        src/dfu_suffix_generator.c
        src/crc.c
)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set (SUFFIX_GEN dfu_suffix_generator)
add_executable(${SUFFIX_GEN} ${SOURCE_FILES})
target_link_libraries(${SUFFIX_GEN} )
target_include_directories(${SUFFIX_GEN} PRIVATE ${INCLUDE_DIRS})

