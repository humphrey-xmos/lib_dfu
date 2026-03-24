// Copyright 2011-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_DEFAULT_CONF_H
#define DFU_DEFAULT_CONF_H

#ifdef __dfu_conf_h_exists__
#include "dfu_conf.h"
#endif

/** Main control for the function of the DFU library. 
 * When enabled, the application must provide "-lquadflash" to link the flash library.
 * When disabled will include empty stubs for the API functions. These stubs are weak and can be overridden locally.
 */
#ifndef DFU_ENABLE
#define DFU_ENABLE 1
#endif

/** Main control for the USB functionality of the DFU library. 
 * When enabled, the DFU library will include USB support. Build with lib_xud or lib_xua.
 * When disabled, USB support will be excluded. Other transports can be used.
 */
#ifndef DFU_USB_EN
#define DFU_USB_EN 0
#endif

#ifndef DFU_BCD_DEVICE
#define DFU_BCD_DEVICE 0x0100
#endif

#ifdef __DOXYGEN__
/** User defined flash device specification for DFU to use.
 * 
 * If not defined, the default flash device list in dfu_flashlib_user.c is used.
 * This should be defined as a fl_DeviceSpec or fl_QuadDeviceSpec structure,
 * depending on whether DFU_QUAD_SPI_FLASH is set.
 */
#define DFU_USER_FLASH_DEVICE
#endif

/** Whether DFU uses Quad SPI Flash, or older SPI flash (when 0) */
#ifndef DFU_QUAD_SPI_FLASH
#define DFU_QUAD_SPI_FLASH 1
#endif

/** Number of bytes transferred in each DFU packet on the given physical transport */
#ifndef DFU_TRANSFER_SIZE_BYTES
#define DFU_TRANSFER_SIZE_BYTES 64
#endif

/** Number of bytes in a flash page for the target device */
#ifndef DFU_FLASH_PAGE_SIZE_BYTES
#define DFU_FLASH_PAGE_SIZE_BYTES 256
#endif

/** Number of DFU packets per flash page */
#ifndef NUM_TRANSFER_BLOCKS_PER_FLASH_PAGE
#define NUM_TRANSFER_BLOCKS_PER_FLASH_PAGE (DFU_FLASH_PAGE_SIZE_BYTES / DFU_TRANSFER_SIZE_BYTES)
#endif

#if (DFU_TRANSFER_SIZE_BYTES > DFU_FLASH_PAGE_SIZE_BYTES)
#error "DFU_TRANSFER_SIZE_BYTES must not be greater than DFU_FLASH_PAGE_SIZE_BYTES"
#endif
#if (DFU_FLASH_PAGE_SIZE_BYTES % DFU_TRANSFER_SIZE_BYTES)
#error DFU_FLASH_PAGE_SIZE_BYTES should be a multiple of DFU_TRANSFER_SIZE_BYTES
#endif

#ifndef DFU_CONFIG_USB_INBAND_FUNCTIONS
#define DFU_CONFIG_USB_INBAND_FUNCTIONS 0
#endif

/* Defines flash area to erase on first DFU download request received
 *
 * Flash library will round it up to the nearest sector, e.g. 4KB
 *
 */
#ifndef FLASH_MAX_UPGRADE_SIZE
#define FLASH_MAX_UPGRADE_SIZE (512 * 1024)
#endif

/** Clock block for use by DFU flash operations */
#ifndef CLKBLK_DFU_FLASHLIB
#ifdef __xcore__
#define CLKBLK_DFU_FLASHLIB XS1_CLKBLK_1
#endif
#endif

/** Main control for the DFU lib_control_device server functionality.
 * When enabled, the DFU library will include the control server for non-USB transports.
 * When disabled, the control server will be excluded.
 * \note Requires lib_device_control to be added to `APP_DEPENDENT_MODULES` to use.
 */
#ifndef DFU_CONTROL_SERVER
#define DFU_CONTROL_SERVER 0
#endif

#endif /* DFU_DEFAULT_CONF_H */
