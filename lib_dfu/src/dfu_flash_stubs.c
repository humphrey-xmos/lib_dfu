// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifdef DFU_FLASH_UNIT_TEST
#include <assert.h>
#include <stdbool.h>
#include "dfu_flash.h"
#include "dfu_flash_result.h"

__attribute__((weak))
enum flash_locate_boot_upgrade_slot_result
  flash_locate_boot_upgrade_slot(unsigned *address);

enum flash_locate_boot_upgrade_slot_result
  flash_locate_boot_upgrade_slot(unsigned *address)
{
  assert(0);
  return -1;
}

__attribute__((weak))
enum flash_locate_data_upgrade_slot_result
  flash_locate_data_upgrade_slot(unsigned *address);

enum flash_locate_data_upgrade_slot_result
  flash_locate_data_upgrade_slot(unsigned *address)
{
  assert(0);
  return -1;
}

__attribute__((weak))
enum flash_erase_sector_async_result
  flash_erase_sector_async(unsigned address);

enum flash_erase_sector_async_result
  flash_erase_sector_async(unsigned address)
{
  assert(0);
  return -1;
}

__attribute__((weak))
int flash_is_busy(void);

int flash_is_busy(void)
{
  assert(0);
  return false;
}

__attribute__((weak))
int flash_is_first_whole_page_in_sector(unsigned address);

int flash_is_first_whole_page_in_sector(unsigned address)
{
  assert(0);
  return false;
}

__attribute__((weak))
int flash_is_sector_erased(unsigned address);

int flash_is_sector_erased(unsigned address)
{
  assert(0);
  return false;
}

__attribute__((weak))
enum flash_set_write_disable_result
  flash_set_write_disable(void);

enum flash_set_write_disable_result
  flash_set_write_disable(void)
{
  assert(0);
  return -1;
}

__attribute__((weak))
enum flash_write_page_async_result
  flash_write_page_async(unsigned address, const char page[]);

enum flash_write_page_async_result
  flash_write_page_async(unsigned address, const char page[])
{
  assert(0);
  return -1;
}

__attribute__((weak))
bool flash_verify_page(unsigned address, const char page[]);

bool flash_verify_page(unsigned address, const char page[])
{
  assert(0);
  return false;
}

__attribute__((weak))
int flash_get_page_size(void);

int flash_get_page_size(void)
{
  assert(0);
  return -1;
}

__attribute__((weak))
int flash_get_data_partition_base(void);

int flash_get_data_partition_base(void)
{
  assert(0);
  return -1;
}

__attribute__((weak))
int flash_get_size(void);

int flash_get_size(void)
{
  assert(0);
  return -1;
}

#endif
