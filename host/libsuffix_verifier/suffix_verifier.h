// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef __suffix_verifier_h__
#define __suffix_verifier_h__

#include <stddef.h>

int verify_dfu_suffix(const unsigned char *file, size_t num_bytes,
                      unsigned short vendor_id,
                      unsigned short product_id,
                      unsigned short bcd_device,
                      size_t *suffix_length, char msg[256]);

#endif
