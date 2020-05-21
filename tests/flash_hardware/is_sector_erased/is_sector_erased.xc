// Copyright (c) 2020, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include <print.h>
#include <quadflash.h>

#define _Bool int
#include <stdbool.h>

#define DEBUG_UNIT TEST
#define DEBUG_PRINT_ENABLE_TEST 0
#include "debug_print.h"

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

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
  bool erased, expected;

  assert(argc == 2);

  ret = fl_connectToOneDevice(ports, spec);
  assert(ret == 0);

  erased = flash_is_sector_erased(0);

  ret = fl_disconnect();
  assert(ret == 0);

  unsafe {
    expected = argv[1][0] == 'E';
  }

  if (expected != erased) {
    debug_printf("expected %d actual %d\n", expected, erased);
    assert(0);
  }

  printstr("PASS\n");
  return 0;
}
