cmake_minimum_required(VERSION 3.16) # Note older version to support Buster

project(host)

add_subdirectory(suffix_generator)
add_subdirectory(xmosdfu)

# Raspberry Pi
if ((${CMAKE_SYSTEM_NAME} MATCHES "Linux") AND ((${CMAKE_SYSTEM_PROCESSOR} MATCHES "arm") OR (${CMAKE_SYSTEM_PROCESSOR} MATCHES "aarch64")))
add_subdirectory(dfu_i2c)
endif()
