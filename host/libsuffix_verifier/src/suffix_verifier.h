// Copyright 2020-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef __suffix_verifier_h__
#define __suffix_verifier_h__

#include <stddef.h>

#define MSG_BUFFER_BYTES 256

enum suffix_result {
  SUFFIX_OK = 0,
  SUFFIX_TOO_SMALL = 1,
  SUFFIX_CHECKSUM_MISMATCH = 2,
  SUFFIX_LENGTH_FIELD_MISMATCH = 3,
  SUFFIX_SIGNATURE_MISMATCH = 4,
  SUFFIX_BCD_DFU_MISMATCH = 5,
  SUFFIX_VENDOR_ID_MISMATCH = 6,
  SUFFIX_PRODUCT_ID_MISMATCH = 7,
  SUFFIX_BCD_DEVICE_MISMATCH = 8
};

int verify_dfu_suffix(const unsigned char *file, size_t num_bytes,
                      unsigned short vendor_id,
                      unsigned short product_id,
                      unsigned short bcd_device,
                      size_t *suffix_length, char msg[MSG_BUFFER_BYTES]);

#endif
