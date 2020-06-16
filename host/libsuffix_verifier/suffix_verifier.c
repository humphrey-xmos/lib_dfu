// Copyright (c) 2020, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <stdbool.h>
#include <memory.h>
#include <stdint.h>
#include <stdlib.h>
#include <stddef.h>

// byte order portability
#ifdef _WIN32
#define le16toh(x) (x) // Windows little endian only
#define le32toh(x) (x)
#elif __APPLE__
#include <libkern/OSByteOrder.h>
#define le16toh(x) OSSwapLittleToHostInt16(x)
#define le32toh(x) OSSwapLittleToHostInt32(x)
#else
#include <endian.h>
#endif

#include "dfu_suffix.h"
#include "crc.h"

int verify_dfu_suffix(const unsigned char *file, size_t num_bytes,
                      unsigned short vendor_id,
                      unsigned short product_id,
                      unsigned short bcd_device,
                      size_t *suffix_length, char msg[256])
{
  if (num_bytes < sizeof(struct dfu_suffix)) {
    sprintf(msg, "file is too small (need at least suffix length %lu)\n",
                  sizeof(struct dfu_suffix));
    return 1;
  }

  struct dfu_suffix suffix;
  for (int i = 0; i < sizeof(struct dfu_suffix); i++) {
    ((unsigned char*)&suffix)[i] = file[num_bytes - 1 - i];
  }

  unsigned crc = crc_init();
  for (unsigned i = 0; i < num_bytes - sizeof(struct dfu_suffix); i++) {
    crc_step(&crc, file[i]);
  }
  crc = crc_finish(crc);

  // convert from hard little endian order after deserialisation
  suffix.crc = le32toh(suffix.crc);
  suffix.bcd_dfu = le16toh(suffix.bcd_dfu);
  suffix.vendor_id = le16toh(suffix.vendor_id);
  suffix.product_id = le16toh(suffix.product_id);
  suffix.bcd_device = le16toh(suffix.bcd_device);

  if (suffix.crc != crc) {
    sprintf(msg, "checksum mismatch: suffix 0x%08X computed 0x%08X\n",
                  suffix.crc, crc);
    return 2;
  }

  if (suffix.suffix_length != sizeof(struct dfu_suffix)) {
    sprintf(msg, "suffix length field: suffix 0x%02X should be 0x%02X\n",
                  suffix.suffix_length, (int)sizeof(struct dfu_suffix));
    return 3;
  }

  const uint8_t signature[] = DFU_SIGNATURE;
  if (memcmp(suffix.signature, signature, sizeof(signature)) != 0) {
    sprintf(msg, "signature field: is 0x%02X%02X%02X should be 0x%02X%02X%02X\n",
                  suffix.signature[0], suffix.signature[1], suffix.signature[2],
                  signature[0], signature[1], signature[2]);
    return 4;
  }

  if (suffix.bcd_dfu != DFU_BCD) {
    sprintf(msg, "bcdDFU field: suffix 0x%04X should be 0x%04X\n",
                  suffix.bcd_dfu, DFU_BCD);
    return 5;
  }

  if (suffix.vendor_id != 0xFFFF && vendor_id != 0xFFFF &&
      suffix.vendor_id != vendor_id) {
    sprintf(msg, "vendor ID mismatch: suffix 0x%04X expected 0x%04X\n",
                  suffix.vendor_id, vendor_id);
    return 6;
  }

  if (suffix.product_id != 0xFFFF && product_id != 0xFFFF &&
      suffix.product_id != product_id) {
    sprintf(msg, "product ID mismatch: suffix 0x%04X expected 0x%04X\n",
                  suffix.product_id, product_id);
    return 7;
  }

  if (suffix.bcd_device != 0xFFFF && bcd_device != 0xFFFF &&
      suffix.bcd_device != bcd_device) {
    sprintf(msg, "bcdDevice mismatch: suffix 0x%04X expected 0x%04X\n",
                  suffix.bcd_device, bcd_device);
    return 8;
  }

  *suffix_length = sizeof(struct dfu_suffix);
  return 0;
}
