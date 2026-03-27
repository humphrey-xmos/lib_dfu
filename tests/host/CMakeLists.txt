cmake_minimum_required(VERSION 3.21)

project(host)

# Only crc_algorithm test is a custom build, other use suffix_generator binary directly
add_subdirectory(suffix_generator/crc_algorithm)

include(../../host/libsuffix_verifier/libsuffix_verifier.cmake)

add_subdirectory(suffix_verifier/basic_verifier)
add_subdirectory(suffix_verifier/error_conditions)
add_subdirectory(suffix_verifier/ignore_id)