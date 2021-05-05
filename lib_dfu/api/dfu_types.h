// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef __dfu_types_h__
#define __dfu_types_h__

#define DFU_BLOCK_SIZE_MAX_BYTES 512
#define DFU_PAGE_SIZE_MAX_BYTES 256

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

/**
 * DFU interface state machine
 */
enum dfu_state {
  APP_IDLE,
  APP_DETACH,
  DFU_IDLE,
  DFU_DNLOAD_SYNC,
  DFU_DNBUSY,
  DFU_DNLOAD_IDLE,
  DFU_MANIFEST_SYNC,
  DFU_MANIFEST,
  DFU_MANIFEST_WAIT_RESET,
  DFU_UPLOAD_IDLE,
  DFU_ERROR
};

/**
 * DFU device status code
 */
enum dfu_status {
  DFU_OK,
  ERR_TARGET,
  ERR_FILE,
  ERR_WRITE,
  ERR_ERASE,
  ERR_CHECK_ERASED,
  ERR_PROG,
  ERR_VERIFY,
  ERR_ADDRESS,
  ERR_NOTDONE,
  ERR_FIRMWARE,
  ERR_VENDOR,
  ERR_USBR,
  ERR_POR,
  ERR_UNKNOWN,
  ERR_STALLED_PKT
};

/**
 * Return value of GETSTATUS request
 */
struct dfu_getstatus {
  enum dfu_status status;
  enum dfu_state state;
  unsigned poll_timeout_msec;
};

#endif
