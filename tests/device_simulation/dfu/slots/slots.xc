// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <platform.h>
#include <stdio.h>
#include <print.h>
#include <string.h>

#define _Bool int
#include <stdbool.h>

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

#define DEBUG_UNIT TEST
#define DEBUG_PRINT_ENABLE_TEST 0
#include "debug_print.h"

#include "dfu.h"
#include "dfu_flash.h"
#include "dfu_flash_result.h"

unsigned boot_slot_address = 0;
unsigned data_slot_address = 0;

unsigned first_test_address = 0;
unsigned erase_sector_address = 0;

bool flash_is_first_whole_page_in_sector(unsigned address)
{
  first_test_address = address;
  return true;
}

enum flash_erase_sector_async_result
  flash_erase_sector_async(unsigned address)
{
  erase_sector_address = address;
  return 0;
}

bool flash_is_busy(void)
{
  return false;
}

enum flash_locate_boot_upgrade_slot_result
  flash_locate_boot_upgrade_slot(unsigned &address)
{
  address = boot_slot_address;
  return 0;
}

enum flash_locate_data_upgrade_slot_result
  flash_locate_data_upgrade_slot(unsigned &address)
{
  address = data_slot_address;
  return 0;
}

bool flash_is_sector_erased(unsigned address)
{
  return false;
}

enum flash_set_write_disable_result
  flash_set_write_disable(void)
{
  return 0;
}

enum flash_write_page_async_result
  flash_write_page_async(unsigned address, const char page[])
{
  return 0;
}

bool flash_verify_page(unsigned address, const char page[])
{
  return true;
}

int flash_get_page_size(void)
{
  return 0;
}

int flash_get_data_partition_base(void)
{
  return 1048576;
}

int main(unsigned argc, char * unsafe argv[argc])
{
  struct dfu_getstatus getstatus;
  enum dfu_state state;
  char block[DFU_BLOCK_SIZE_MAX_BYTES];
  int partition = -1;
  unsigned expected = ~0;
  int ret;

  assert(argc == 5);

  unsafe {
    sscanf(argv[1], "%u", &boot_slot_address);
    sscanf(argv[2], "%u", &data_slot_address);
    sscanf(argv[3], "0x%x", &partition);
    sscanf(argv[4], "%u", &expected);
  }

  ret = dfu_locate_upgrade_slots();
  assert(ret == 0);

  state = dfu_getstate();
  assert(state == APP_IDLE);

  dfu_detach();
  state = dfu_getstate();
  assert(state == APP_DETACH);

  dfu_bus_reset();
  state = dfu_getstate();
  assert(state == DFU_IDLE);

  int block_num = partition == 2 ? DFU_BLOCK_NUM_DATA_IMAGE_MARKER : 0;
  dfu_dnload(block_num, sizeof(block), block);
  
  state = dfu_getstate();
  assert(state == DFU_DNLOAD_SYNC);

  getstatus = dfu_getstatus();
  assert(getstatus.status == DFU_OK);

  assert(erase_sector_address == expected);
  assert(first_test_address == expected);

  printstr("PASS\n");
  return 0;
}
