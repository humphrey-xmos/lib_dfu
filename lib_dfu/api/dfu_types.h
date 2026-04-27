// Copyright 2019-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_TYPES_H
#define DFU_TYPES_H

/**
 * Divide 16bit block number space in half. Top bit cleared is for boot
 * partition. Top bit set (the below marker value) is for data partition.
 *
 * Note that this creates a gap in the sequence of block numbers presented
 * while sending a boot image followed by a data image. For instance, it the
 * sequence goes 0 up to 8,000 for a boot image. Then jump to 32,768 and
 * continue incrementing to 40,000 for the data image.
 *
 * Currently not intended as actual specification-compliant deployment, in
 * the future we will need to check the gap does not upset some driver
 * software or third party utilities.
 */
#define DFU_BLOCK_NUM_DATA_IMAGE_MARKER 0x8000

#define DFU_GET_STATE_PAYLOAD_SIZE_BYTES 1
#define DFU_GET_STATUS_PAYLOAD_SIZE_BYTES 6

#define DFU_GETSTATE_INDEX 0
#define DFU_GETSTATUS_STATUS_INDEX 0
#define DFU_GETSTATUS_POLL_TIMEOUT_INDEX 1
#define DFU_GETSTATUS_POLL_TIMEOUT_BYTES 3
#define DFU_GETSTATUS_STATE_INDEX 4

#define DFU_GETDESCRIPTOR_PAYLOAD_SIZE_BYTES 4
#define DFU_GETDESCRIPTOR_BCD_DEVICE_INDEX 0
#define DFU_GETDESCRIPTOR_FUNC_ATTRS_INDEX 2
#define DFU_GETDESCRIPTOR_MODE_FLAG_INDEX 3

#define DFU_MODE_RUNTIME 1
#define DFU_MODE_DFU 2

#define DFU_ATTR_CAN_DOWNLOAD              (1u << 0)
#define DFU_ATTR_CAN_UPLOAD                (1u << 1)
#define DFU_ATTR_MANIFESTATION_TOLERANT    (1u << 2)
#define DFU_ATTR_WILL_DETACH               (1u << 3)
// DFU functional attributes
#define DFU_FUNC_ATTRS (DFU_ATTR_CAN_UPLOAD | DFU_ATTR_CAN_DOWNLOAD | DFU_ATTR_WILL_DETACH | DFU_ATTR_MANIFESTATION_TOLERANT)

/**
 * DFU request types
 * 
 * Largely follows the USB DFU class specification requests, with some additional custom requests
 * for non-USB transports and deferred actions.
 * Deferred action requests are not actual requests sent by the host, but are used internally to
 * indicate slow operations to carry out after responding to the initial request, such as flash
 * programming and rebooting, which cannot be completed within the time constraints of a single
 * request/response transaction.
 */
enum dfu_cmd_request {
  // USB spec DFU commands
  DFU_DETACH = 0,
  DFU_DNLOAD = 1,
  DFU_UPLOAD = 2,
  DFU_GETSTATUS = 3,
  DFU_CLRSTATUS = 4,
  DFU_GETSTATE = 5,
  DFU_ABORT = 6, // TODO - fully support

  // XMOS custom DFU commands - values chosen to avoid conflict with standard DFU requests
  XMOS_DFU_BUS_RESET = 9,       //!< For emulating bus/device reset on transports other than USB.
  XMOS_DFU_GET_DESCRIPTOR = 10, //!< For emulating getting a descriptor on transports other than USB.

  // Not actual requests, used internally to indicate deferred actions to be taken after responding to a request.
  DFU_DEFERRED_ACTION_REBOOT = 20,
  DFU_DEFERRED_ACTION_REBOOT_TO_DFU = 21,
  DFU_DEFERRED_ACTION_REVERT_FACTORY = 22,  // Triggered from REVERTFACTORY in DFU_IDLE

  DFU_DEFERRED_ACTION_FLASH_CONNECT = 30,   // Triggered from bus reset in APP_DETACH
  DFU_DEFERRED_ACTION_FLASH_WRITE = 31,     // Triggered from get-status request
  DFU_DEFERRED_ACTION_FLASH_MANIFEST = 32,  // Triggered from get-status request

  XMOS_DFU_GETPROFILE = 40, // For getting DFU profile data such as command execution time, for profiling and testing purposes.

  /** Additional command that erases only the first flash sector of the upgrade image, to revert to the factory image */
  XMOS_DFU_REVERTFACTORY = 0xF1, // For lib_device_control access this will be 0x71 due to read bit
};

/**
 * DFU state machine states, from USB DFU spec v1.1
 */
enum dfu_state {
  STATE_APP_IDLE = 0,
  STATE_APP_DETACH = 1,
  STATE_DFU_IDLE = 2,
  STATE_DFU_DOWNLOAD_SYNC = 3,
  STATE_DFU_DOWNLOAD_BUSY = 4,
  STATE_DFU_DOWNLOAD_IDLE = 5,
  STATE_DFU_MANIFEST_SYNC = 6,
  STATE_DFU_MANIFEST = 7,
  STATE_DFU_MANIFEST_WAIT_RESET = 8,
  STATE_DFU_UPLOAD_IDLE = 9,
  STATE_DFU_ERROR = 10
};

/**
 * DFU device status code, from USB DFU spec v1.1
 */
enum dfu_status {
  DFU_OK,
  DFU_errTARGET,
  DFU_errFILE,
  DFU_errWRITE,
  DFU_errERASE,
  DFU_errCHECK_ERASED,
  DFU_errPROG,
  DFU_errVERIFY,
  DFU_errADDRESS,
  DFU_errNOTDONE,
  DFU_errFIRMWARE,
  DFU_errVENDOR,
  DFU_errUSBR,
  DFU_errPOR,
  DFU_errUNKNOWN,
  DFU_errSTALLED_PKT
};

/**
 * Return value of GETSTATUS request, in machine native types, from USB DFU spec v1.1
 */
struct dfu_getstatus {
  enum dfu_status status; /**< DFU Status code */
  enum dfu_state state; /**< DFU Current state */
  unsigned poll_timeout_msec; /**< Poll timeout in milliseconds */
};

/**
 * DFU profile data for timing and testing purposes, returned by XMOS_DFU_GETPROFILE request
 */
struct dfu_profile_data {
    unsigned command_time;
    unsigned command_index;
    unsigned index_total;
    unsigned cmd;
};

#endif
