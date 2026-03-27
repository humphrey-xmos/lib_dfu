cmake_minimum_required(VERSION 3.12)

project("test_status")

# Force release mode so that all the DLLs are statically linked
set (CMAKE_BUILD_TYPE "Release" CACHE STRING "Only Release mode is allowed" FORCE)

include(../../../../lib_device_control/host/host_build_i2c.cmake)

set (INCLUDE_DIRS 
        "../../../host/api"
        "../../../host/dfu_i2c/src"
        "../../../host/libsuffix_verifier/src"
        "../../../lib_dfu/api"
        "../../../lib_dfu/src"
        "src"
)

set (SOURCE_FILES
        ../../../host/dfu_i2c/src/argument_parser.c
        ../../../host/dfu_i2c/src/hal.c
        ../../../host/dfu_i2c/src/input_reader.c
        ../../../host/dfu_i2c/src/operations.c
        ../../../host/dfu_i2c/src/dfu_utils.c
        ../../../host/dfu_i2c/src/labels.c
        ../../../host/libsuffix_verifier/src/crc.c
        ../../../host/libsuffix_verifier/src/suffix_verifier.c
)

set (DFUCTRL_LIB dfuctrl_i2c_1.0)
set (DFUCTRL_APP dfu_i2c)
add_compile_definitions(nologo CONTROL_USE_I2C CONTROL_RPI)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/../lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/../bin)

add_library(${DFUCTRL_LIB} STATIC ${SOURCE_FILES})
target_include_directories(${DFUCTRL_LIB} PUBLIC ${INCLUDE_DIRS})
target_link_libraries(${DFUCTRL_LIB} control_i2c_host)

add_executable(${DFUCTRL_APP} src/main.c)
target_include_directories(${DFUCTRL_APP} PUBLIC "api")
if (${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    target_link_libraries(${DFUCTRL_APP} ${DFUCTRL_LIB})
else()
    target_link_libraries(${DFUCTRL_APP} ${DFUCTRL_LIB} m)
endif()
