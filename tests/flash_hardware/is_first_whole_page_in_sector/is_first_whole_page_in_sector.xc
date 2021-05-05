// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <platform.h>
#include <print.h>
#include <quadflash.h>

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

#define _Bool int
#include <stdbool.h>

#include "quadflash_extra.h"
#include "dfu_flash.h"

fl_QSPIPorts ports = {
  PORT_SQI_CS, PORT_SQI_SCLK, PORT_SQI_SIO, XS1_CLKBLK_1
};

fl_QuadDeviceSpec spec = { // IS25LQ016B
  0, 256, 8192, 3, 8, 0x9F, 0, 3, 0x9D4015, 0x20, 4096, 0x06, 0x04,
  PROT_TYPE_NONE, {{0,0},{0x00,0x00}}, 0x02, 0xEB, 1,
  SECTOR_LAYOUT_REGULAR, {4096,{0,{0}}}, 0x05, 0x01, 0x01
};

int main(void)
{
  int ret;

  const int sectors[] = {0, 1, 2, 3, 100, 511};
  const int offsets[] = {0, 1, 128, 256, 4095};
  const bool answers[] = {true, true, true, false, false};

  ret = fl_connectToOneDevice(ports, spec);
  assert(ret == 0);

  for (int i = 0; i < sizeof(offsets) / sizeof(int); i++) {
    for (int j = 0; j < sizeof(sectors) / sizeof(int); j++) {
      unsigned sector_address = spec.sectorSizes.regularSectorSize * sectors[j];
      bool is_first = flash_is_first_whole_page_in_sector(sector_address + offsets[i]);
      assert(is_first == answers[i]);
    }
  }

  ret = fl_disconnect();
  assert(ret == 0);

  printstr("PASS\n");
  return 0;
}
