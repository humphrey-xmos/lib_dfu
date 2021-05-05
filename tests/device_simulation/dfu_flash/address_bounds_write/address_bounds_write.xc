// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <print.h>
#include <quadflash.h>

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

#define DEBUG_UNIT TEST
#define DEBUG_PRINT_ENABLE_TEST 0
#include "debug_print.h"

#include "dfu_flash.h"

extern const fl_QuadDeviceSpec * unsafe g_flashAccess;

fl_QuadDeviceSpec spec[] = { // IS25LQ016B
  { 0, 256, 8192, 3, 8, 0x9F, 0, 3, 0x9D4015, 0x20, 4096, 0x06, 0x04,
    PROT_TYPE_NONE, {{0,0},{0x00,0x00}}, 0x02, 0xEB, 1,
    SECTOR_LAYOUT_REGULAR, {4096,{0,{0}}}, 0x05, 0x01, 0x01
  }
};

int fl_getSectorContaining(unsigned address)
{
  return address / 4096;
}

int fl_getSectorAddress(int sectorNum)
{
  return sectorNum * 4096;
}

unsigned fl_getDataPartitionBase(void)
{
  return 1048576;
}

int fl_getNumSectors(void)
{
  return 512;
}

int fl_setWritability(int enable)
{
  return 0;
}

int fl_getSectorEndAddress(int sectorNum)
{
  return (sectorNum + 1) * 4096;
}

unsigned fl_getFlashSize(void)
{
  return 2097152;
}

unsigned fl_getPageSize(void)
{
  return 256;
}

void fl_int_write(unsigned char cmd,
                  unsigned int pageAddress, 
                  const unsigned char data[num_bytes],
                  unsigned int num_bytes)
{
  // nothing
}

int main(void)
{
  int ret;
  char page[256] = {0};
  const int good[] = {4096, 16384, 1048575, 1052672, 2097151};
  const int bad[] = {0, 1, 4095, 1048576, 1048577, 1052671, 2097152, 8388608};

  unsafe {
    g_flashAccess = &spec[0];
  }

  for (int i = 0; i < sizeof(good) / sizeof(int); i++) {
    debug_printf("%d (good)\n", good[i]);
    ret = flash_write_page_async(good[i], page);
    assert(ret == 0);
  }

  for (int i = 0; i < sizeof(bad) / sizeof(int); i++) {
    debug_printf("%d (bad)\n", bad[i]);
    ret = flash_write_page_async(bad[i], page);
    assert(ret != 0);
  }

  printstr("PASS\n");
  return 0;
}
