// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef __dfu_h__
#define __dfu_h__

#include <stddef.h>
#include <quadflash.h>

#define _Bool int
#include <stdbool.h>

#include "dfu_types.h"

/**
 * Perform sanity checks of flash device about to be used for firmware upgrade
 *
 * Caller chooses when to call this. Comprises a set of assertions to verify
 * that the implementation relies on. Caller is required to connect to flash
 * explicitly using quadflash library, and it will do that using the same flash
 * specification as the one passed in here.
 *
 * Flash connection is not necessary
 *
 * \param  spec              Flash specification to check
 *
 * \return Whether specification is suitable for use by this library
 */
bool dfu_is_flash_suitable(const fl_QuadDeviceSpec spec[1]);

/**
 * Invoke scanning of data partition to locate address of boot upgrade and data
 * upgrade images. These are where a potential upgrade will be written to.
 *
 * Caller decides when scanning should be done, since it is a fairly time
 * consuming operation (250ms for typical factory image size at time of writing)
 *
 * Note that caller must have first connected to flash using quadflash library
 *
 * \return                   Zero for success or a non-zero error code
 */
int dfu_locate_upgrade_slots(void);

/**
 * DFU GETSTATE request
 *
 * \return Current interface state
 */
enum dfu_state dfu_getstate(void);

/**
 * DFU DETACH request
 */
void dfu_detach(void);

/**
 * Simulate a USB bus reset
 *
 * Normal implementation based on USB DFU specification would undergo an actual
 * bus reset. In our implementation we want to don't add any code for handling
 * USB reset into DFU, and we also want to support DFU over I2C with this code.
 * Therefore we call a function to advance the state machine. It does nothing
 * else than change the interface state.
 */
void dfu_bus_reset(void);

/**
 * Tell the state machine that detach timeout occured
 *
 * The usage scheme is for the caller to implement the timeout based on value
 * exposed in USB descriptors. Adding timers in the library doesn't seem very
 * useful, it's best for the caller to integrate.
 *
 * In non-USB applications (such as I2S/I2C) we leave this timeout facility
 * unused (never call this function). In USB applications it is largely there
 * for specification compliance (like the bus reset).
 */
void dfu_timeout_detach(void);

/**
 * DFU DNLOAD request
 *
 * Block size can vary, but normally doesn't. Typical use is a sequence of fixed
 * size blocks until the end of an image, then one zero-size block to finish.
 *
 * Note that at this point the caller must have connected to the flash using
 * quadflash library. While DNLOAD request does no erasing or writing work, it
 * needs to know the page size to being converting blocks to pages.
 *
 * \param block_num          Block number
 * \param block_size_bytes   Block size in bytes
 * \param block              Block contents
 */
void dfu_dnload(unsigned short block_num, size_t block_size_bytes,
                const char block[DFU_BLOCK_SIZE_MAX_BYTES]);

/**
 * DFU GETSTATUS request
 *
 * At time of writing, all flash programming work is done as part of GETSTATUS.
 * This means that a DNLOAD request completes immediately and does not cause
 * any flash erasing or writing.
 *
 * Note that at this point the caller must have connected to the flash using
 * quadflash library.
 *
 * \return Status code, poll timeout value and current interface state
 */
struct dfu_getstatus dfu_getstatus(void);

/**
 * DFU CLRSTATUS request
 */
void dfu_clrstatus(void);

/**
 * Get detailed information about an error
 *
 * In addition to status code from specification, an error state is accompanied
 * by an additional value, 'error information'. Depending on context of given
 * error, this could be a return value from a function that led to the error.
 * It could be state that led to an invalid transition. Often it will be just
 * zero.
 *
 * You need to refer to implementation to interpret a specific error scenario
 *
 * \return Error details
 */
int dfu_get_error_info(void);

#endif
