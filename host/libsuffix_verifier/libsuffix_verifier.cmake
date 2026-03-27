

add_library(suffix_verifier INTERFACE)

target_sources(suffix_verifier INTERFACE
        ${CMAKE_CURRENT_LIST_DIR}/src/suffix_verifier.c
        ${CMAKE_CURRENT_LIST_DIR}/src/crc.c)

target_include_directories(suffix_verifier INTERFACE 
        ${CMAKE_CURRENT_LIST_DIR}/../api
        ${CMAKE_CURRENT_LIST_DIR}/src)
