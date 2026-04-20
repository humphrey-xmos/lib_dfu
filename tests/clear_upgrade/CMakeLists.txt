cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(clear_upgrade)

# target: choose the target platform
set(APP_HW_TARGET XK-EVK-XU316)

set(APP_DEPENDENT_MODULES 
  lib_dfu
)

set(APP_COMPILER_FLAGS
  -O2
  -g
  -lquadflash
  -report
  -Wall
  -Wextra
  -Wshadow
  -Wconversion
  -Wdiv-by-zero
  -Wfloat-equal
  -Wsign-compare
)

set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

XMOS_REGISTER_APP()
