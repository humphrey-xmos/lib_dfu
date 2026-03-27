# This exists to test the Makefile build of lib_dfu

TARGET = xk-voice-l71.xn

APP_NAME =

XCC_FLAGS  = -O3 -mno-dual-issue -g -report -DDFU_BCD_DEVICE=0x0101 ../config.xscope

XCC_MAP_FLAGS = -lquadflash


USED_MODULES = lib_dfu lib_i2c(>=6.4.1) lib_device_control(>=5.0.1)

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
