// Copyright 2019-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_H
#define DFU_H

#include <stddef.h>
#include <stdint.h>
#include <xccompat.h>

#include "dfu_default_conf.h"
#include "dfu_types.h"

/** API function return values */
enum dfu_api_status {
  DFU_API_SUCCESS = 0,
  DFU_API_ERROR = 1,
  DFU_API_DATA_LENGTH_ERROR = 2,
  DFU_API_BAD_PARAM = 3
};

/** DFU request response structure return type
 */
struct dfu_cmd_response {
  enum dfu_api_status status; /**< The status of the DFU request */
  int32_t return_data_len; /**< The length of the data returned by the DFU request, only used for read operations. */
  enum dfu_cmd_request deferred_request; /**< The deferred DFU request, if any, used to action slow operations. */
};

/* From USB DFU spec v1.1 
 *
 * bRequest,      wValue,   wIndex,   wLength,  Data
 * -------------------------------------------------
 * DFU_DETACH     wTimeout  Interface Zero      None
 * DFU-DNLOAD     wBlockNum Interface wLength   Block
 * DFU_UPLOAD     wBlockNum Interface wLength   Block
 * DFU_GETSTATUS  Zero      Interface 6         Status
 * DFU_CLRSTATUS  Zero      Interface Zero      None
 * DFU_GETSTATE   Zero      Interface 1         State
 * DFU_ABORT      Zero      Interface Zero      None
 */

/**
 * \defgroup lib_dfu_api API
 * \{
 */

 /**
  * DFU request handling with arguments
  * 
  * \param request the DFU request to handle
  * \param block pointer to the data payload of the request for read/write operations,
  * usage depends on command, for download it's the data block to write,
  * for upload it's the buffer to fill with the data block read from flash,
  * for other commands it's unused and can be null
  * \param block_size_bytes the size of the data block to read/write for upload/download commands, for other commands it's unused and can be 0
  * \param block_num for download command, the block number to write, for other commands it's unused and can be null
  * 
  * \return struct dfu_cmd_response containing status and any return value, usage depends on command,
  * for upload the return_data_len is the size of the block to upload, for other commands it's unused and can be 0,
  * the deferred_request field is used to indicate any slow operations to carry out after responding to the request,
  * such as flash programming and rebooting, which cannot be completed within the time constraints of a single request/response transaction.
  * \retval DFU_API_SUCCESS if command was handled successfully, the value is the upload block-number for upload command, 0 otherwise.
  * \retval DFU_API_ERROR if there was an error handling the command
  * \retval DFU_API_BAD_PARAM if the command or parameters were invalid
  */
struct dfu_cmd_response dfu_request_with_arguments(enum dfu_cmd_request request,
                                                    NULLABLE_ARRAY_OF(uint8_t, block),
                                                    int32_t block_size_bytes,
                                                    NULLABLE_REFERENCE_PARAM(int32_t, block_num));

/**
 * Send request to DFU with no data
 * 
 * \param request the DFU request to send
 * 
 * \return struct dfu_cmd_response identical to dfu_request_with_arguments return value.
 * \retval DFU_API_SUCCESS for status, if command was handled successfully
 * \retval DFU_API_ERROR for status, if there was an error handling the command
 * \retval DFU_API_BAD_PARAM for status, if the command or parameters were invalid
 *
 */
struct dfu_cmd_response dfu_request(enum dfu_cmd_request request);

/** \} */

/* The following functions are deprecated */
/**
 * DFU DETACH request
 */
void dfu_detach(void);

/**
 * Simulate a USB bus reset
 *
 * Normal implementation based on USB DFU specification would undergo an actual
 * bus reset. In our implementation we want to not add any code for handling
 * USB reset into DFU, and we also want to support DFU over I2C with this code.
 * Therefore we call a function to advance the state machine. It does nothing
 * else than change the interface state.
 */
void dfu_bus_reset(void);

/**
 * Tell the state machine that detach timeout occurred
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

#endif
