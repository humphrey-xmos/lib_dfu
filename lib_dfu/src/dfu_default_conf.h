// Copyright 2011-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_DEFAULT_CONF_H
#define DFU_DEFAULT_CONF_H

#ifdef __dfu_conf_h_exists__
#include "dfu_conf.h"
#endif

/**
 * \defgroup lib_dfu_config Configuration Options
 * \{
 */

/** Main control for the function of the DFU library. 
 * When enabled, the application must provide "-lquadflash" to link the flash library.
 * When disabled will include empty stubs for the API functions. These stubs are weak and can be overridden locally.
 */
#ifndef DFU_ENABLE
#define DFU_ENABLE 1
#endif

/** Main control for the USB functionality of the DFU library. 
 * When enabled, the DFU library will include USB support.
 * When disabled, USB support will be excluded. Other transports can be used.
 * \note Requires `lib_xud` or `lib_xua` to be added to `APP_DEPENDENT_MODULES` to use.
 */
#ifndef DFU_USB_EN
#define DFU_USB_EN 0
#endif

/** USB device release number in binary-coded decimal (BCD) format
 * 
 * Used in DFU for identifying the device version.
 * The default value is 0x0100, which corresponds to version 1.00.
 * 
 * Reported to the host via the USB device descriptor when DFU_USB_EN is enabled.
 * Or, when DFU_USB_EN is disabled, this can be accessed by the host using request XMOS_DFU_GET_DESCRIPTOR.
 */
#ifndef DFU_BCD_DEVICE
#define DFU_BCD_DEVICE 0x0100
#endif

#ifdef __DOXYGEN__
/** Optional, user defined flash device specification for DFU to use.
 * 
 * If not defined (default), the libquadflash will attempt to use JEDEC ``JESD216`` Serial Flash
 * Discoverable Parameters (SFDP) to identify the connected flash device and its capabilities.
 * This requires the flash to be SFDP compliant, and may not work with all flash devices.
 * 
 * If DFU_USER_FLASH_DEVICE is defined, this should be defined as a fl_QuadDeviceSpec or 
 * fl_DeviceSpec structure, depending on whether DFU_QUAD_SPI_FLASH is set.
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

/**
 * Whether to enable USB in-band functions for DFU
 * Inband functions occur during the host request transaction.
 * Out-of-band requests are deferred until after the host request has been completed,
 * which require the DFU task to be allocated to a thread.
 */
#ifndef DFU_CONFIG_USB_INBAND_FUNCTIONS
#define DFU_CONFIG_USB_INBAND_FUNCTIONS 0
#endif

/**
 * Defines flash area to erase on first DFU download request received
 *
 * Flash library will round it up to the nearest sector, e.g. 4KB
 */
#ifndef FLASH_MAX_UPGRADE_SIZE
#define FLASH_MAX_UPGRADE_SIZE (512 * 1024)
#endif

/** Clock block for use by DFU flash operations */
#ifndef CLKBLK_DFU_FLASHLIB
#if defined(__xcore__) || defined(__DOXYGEN__)
#define CLKBLK_DFU_FLASHLIB XS1_CLKBLK_1
#endif
#endif

/**
 * Poll timeout for DFU download entry in milliseconds, time taken to find the upgrade image, if it exists and erase the first sector.
 * 
 * The first sector erase can often take significantly longer than subsequent erases, as it may require additional setup such as checking whether an upgrade image exists and its size.
 * 
 * Values shorter than the actual time taken may cause the host to timeout or cause clock-stretching if using I2C.
 */
#ifndef POLL_TIMEOUT_DNLOAD_ENTRY_MSEC
#define POLL_TIMEOUT_DNLOAD_ENTRY_MSEC 150
#endif

/**
 * Poll timeout for DFU download erase in milliseconds, time taken to erase following sectors of the upgrade image, when it exists.
 * 
 * The value should be taken from the Flash memory datasheet, for erase operations.
 * 
 * Values shorter than the actual time taken may cause the host to timeout or cause clock-stretching if using I2C.
 */
#ifndef POLL_TIMEOUT_DNLOAD_ERASE_MSEC
#define POLL_TIMEOUT_DNLOAD_ERASE_MSEC 8
#endif

/**
 * Poll timeout for DFU download first page write in milliseconds, time taken to prepare for the write and write the first page of the upgrade image.
 * 
 * The first page can often take significantly longer to write than subsequent pages, as it may require additional setup such as preparing the flash for writing.
 * 
 * Values shorter than the actual time taken may cause the host to timeout or cause clock-stretching if using I2C.
 */
#ifndef POLL_TIMEOUT_DNLOAD_FIRST_WRITE_MSEC
#define POLL_TIMEOUT_DNLOAD_FIRST_WRITE_MSEC 100
#endif

/**
 * Poll timeout for DFU download write in milliseconds, time taken to write subsequent pages of the upgrade image.
 * 
 * The value should be taken from the Flash memory datasheet, for write operations.
 * 
 * Values shorter than the actual time taken may cause the host to timeout or cause clock-stretching if using I2C.
 */
#ifndef POLL_TIMEOUT_DNLOAD_WRITE_MSEC
#define POLL_TIMEOUT_DNLOAD_WRITE_MSEC 2
#endif

/**
 * Poll timeout for DFU manifest in milliseconds, time taken to write the last page and finalise the write process.
 * 
 * The value should be taken from the Flash memory datasheet, for write operations.
 * 
 * Values shorter than the actual time taken may cause the host to timeout or cause clock-stretching if using I2C.
 */
#ifndef POLL_TIMEOUT_DNLOAD_MANIFEST_MSEC
#define POLL_TIMEOUT_DNLOAD_MANIFEST_MSEC 3
#endif

/**
 * Main control for the DFU lib_control_device server functionality.
 * When enabled, the DFU library will include the control server for non-USB transports.
 * When disabled, the control server will be excluded.
 * \note Requires `lib_device_control` to be added to `APP_DEPENDENT_MODULES` to use.
 */
#ifndef DFU_CONTROL_SERVER
#define DFU_CONTROL_SERVER 0
#endif

/** \} */

#if (DFU_USB_EN && DFU_CONTROL_SERVER)
#error "DFU_CONTROL_SERVER should not be enabled when DFU_USB_EN is enabled, select only one of these options"
#endif

#if (DFU_TRANSFER_SIZE_BYTES > DFU_FLASH_PAGE_SIZE_BYTES)
#error "DFU_TRANSFER_SIZE_BYTES must not be greater than DFU_FLASH_PAGE_SIZE_BYTES"
#endif
#if (DFU_FLASH_PAGE_SIZE_BYTES % DFU_TRANSFER_SIZE_BYTES)
#error DFU_FLASH_PAGE_SIZE_BYTES should be a multiple of DFU_TRANSFER_SIZE_BYTES
#endif

#endif /* DFU_DEFAULT_CONF_H */
