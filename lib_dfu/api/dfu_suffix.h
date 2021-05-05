// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
//
// Based on USB DFU specification
//
#ifndef __dfu_suffix_h__
#define __dfu_suffix_h__

#include <stdint.h>

#define DFU_SIGNATURE {0x44, 0x46, 0x55}
#define DFU_BCD 0x0110

#pragma pack(push, 1)

/**
 * DFU file suffix
 */
struct dfu_suffix {
  
  uint32_t crc; /**< Checksum of file excluding suffix (note that this is
                     different from specification which includes the suffix) */
  
  uint8_t suffix_length; /**< The length of this DFU suffix including CRC */

  uint8_t signature[3]; /**< The unique DFU signature field */

  uint16_t bcd_dfu; /**< DFU specification number, eg 0x0110 */

  uint16_t vendor_id; /**< The vendor ID associated with this file - either
                           FFFFh or must match device's vendor ID */

  uint16_t product_id; /**< The product ID associated with this file - either 
                            FFFh or must match device's product ID */

  uint16_t bcd_device; /**< The release number of the device associated with
                            this file - either FFFFh or a BCD firmware release
                            or version number */
};

#pragma pack(pop)

#endif
