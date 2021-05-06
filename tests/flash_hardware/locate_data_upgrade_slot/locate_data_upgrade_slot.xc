// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <platform.h>
#include <stdio.h>
#include <print.h>
#include <quadflash.h>

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

#define DEBUG_UNIT TEST
#define DEBUG_PRINT_ENABLE_TEST 0
#include "debug_print.h"

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

int main(unsigned argc, char * unsafe argv[argc])
{
  int ret;
  unsigned address = -1;
  unsigned expected = 0;

  assert(argc == 2);
  sscanf(argv[1], "%d", &expected);

  ret = fl_connectToOneDevice(ports, spec);
  assert(ret == 0);

  ret = flash_locate_data_upgrade_slot(address);
  assert(ret == 0);

  debug_printf("%d\n", address);
  assert(address % spec.sectorSizes.regularSectorSize == 0);

  assert(address == expected);

  ret = fl_disconnect();
  assert(ret == 0);

  printstr("PASS\n");
  return 0;
}
