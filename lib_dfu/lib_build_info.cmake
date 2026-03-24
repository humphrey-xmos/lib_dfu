set(LIB_NAME lib_dfu)

set(LIB_VERSION 1.1.0)

# Disable data partition dependency for DFU library, for now
option(NO_DATA_PARTITION "Disable data partition dependency for DFU library" ON)

set(LIB_DEPENDENT_MODULES   "lib_xassert(4.3.2)" "lib_logging(3.4.0)")

set(LIB_INCLUDES            api src src/modules src/usb src/control)

set(LIB_C_SRCS              src/dfu_flashlib_user.c
                            src/modules/fifo.c
                            flash/quad/dfu_flash.c
                            flash/test/dfu_flash_stubs.c)

set(LIB_XC_SRCS             src/dfu.xc
                            src/usb/dfu_usb_requests.xc
                            src/dfu_reboot.xc
                            src/dfu_sub_sm.xc
                            src/control/dfu_control_server.xc)

set(LIB_COMPILER_FLAGS      -Os
                            -g
                            -report
                            -Wall
                            -Wextra
                            -Wshadow
                            -Wconversion
                            -Wdiv-by-zero
                            -Wfloat-equal
                            -Wsign-compare)

if (NOT NO_DATA_PARTITION)
    # TODO: Update lib_flash_data_partition module version... 2.5.0?
    # To use, configure dfu_conf.h with DFU_ENABLE = 2.
    list(APPEND LIB_DEPENDENT_MODULES "lib_flash_data_partition(2.2.0)")
    list(APPEND LIB_C_SRCS flash/partition/dfu_flash.c)
endif()

set(LIB_OPTIONAL_HEADERS    dfu_conf.h)

XMOS_REGISTER_MODULE()
