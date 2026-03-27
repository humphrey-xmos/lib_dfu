cmake_minimum_required(VERSION 3.16) # Note older version to support Buster

project("dfu_i2c")

# Force release mode so that all the DLLs are statically linked
set (CMAKE_BUILD_TYPE "Release" CACHE STRING "Only Release mode is allowed" FORCE)

include(FetchContent)

set(LIB_DEVICE_CONTROL_SOURCE "" CACHE PATH "Use an existing lib_device_control checkout instead of fetching release v5.0.0")
if(LIB_DEVICE_CONTROL_SOURCE)
    set(_LIB_DEVICE_CONTROL_ROOT ${LIB_DEVICE_CONTROL_SOURCE})
else()
    message(STATUS "Fetching lib_device_control v5.0.0 release")
    FetchContent_Declare(lib_device_control
            GIT_REPOSITORY https://github.com/xmos/lib_device_control.git
            GIT_TAG v5.0.0
    )
    FetchContent_GetProperties(lib_device_control)
    if(NOT lib_device_control_POPULATED)
        FetchContent_Populate(lib_device_control)
    endif()
    set(_LIB_DEVICE_CONTROL_ROOT ${lib_device_control_SOURCE_DIR})
endif()

include(${_LIB_DEVICE_CONTROL_ROOT}/host/host_build_i2c.cmake)
include(../libsuffix_verifier/libsuffix_verifier.cmake)

set (INCLUDE_DIRS
        "../api"
        "../common"
        "../../lib_dfu/api"
        "../../lib_dfu/src"
        "src"
)

set (SOURCE_FILES
        src/argument_parser.c
        src/hal.c
        src/input_reader.c
        src/operations.c
        ../common/dfu_utils.c
        src/labels.c
)

set(DFUCTRL_LIB dfuctrl_i2c_1.0)
set(DFUCTRL_APP dfu_i2c)
add_compile_definitions(nologo CONTROL_USE_I2C CONTROL_RPI)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/bin)

if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
    set(FLAGS /O2 /W4)
else()
    set(FLAGS 
            -g
            -O2
            -Wall
            -Wextra
            -Wpedantic
            -Wconversion
            -Wdiv-by-zero
            -Wfloat-equal
            -Wsign-compare
            -Wshadow)
endif()

add_library(${DFUCTRL_LIB} STATIC ${SOURCE_FILES})
target_include_directories(${DFUCTRL_LIB} PUBLIC ${INCLUDE_DIRS})
target_compile_options(${DFUCTRL_LIB} PUBLIC ${FLAGS})
# TODO - make linking with INTERFACE libs PRIVATE
target_link_libraries(${DFUCTRL_LIB} PUBLIC suffix_verifier control_i2c_host)

add_executable(${DFUCTRL_APP} src/main.c)
target_compile_options(${DFUCTRL_APP} PUBLIC ${FLAGS})

if (${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    target_link_libraries(${DFUCTRL_APP} PUBLIC ${DFUCTRL_LIB})
else()
    target_link_libraries(${DFUCTRL_APP} PUBLIC ${DFUCTRL_LIB} m)
endif()
