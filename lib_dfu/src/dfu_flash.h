// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
//
// The original intention is for those functions to be the ones used by the
// DFU implementation, and those only
//
#ifndef __dfu_flash_h__
#define __dfu_flash_h__

#include <xccompat.h>

#define _Bool int
#include <stdbool.h>

#include "dfu_flash_result.h"

enum flash_erase_sector_async_result
  flash_erase_sector_async(unsigned address);

int flash_get_page_size(void);

bool flash_is_busy(void);

bool flash_is_first_whole_page_in_sector(unsigned address);

bool flash_is_sector_erased(unsigned address);

enum flash_locate_boot_upgrade_slot_result
  flash_locate_boot_upgrade_slot(REFERENCE_PARAM(unsigned, address));

enum flash_locate_data_upgrade_slot_result
  flash_locate_data_upgrade_slot(REFERENCE_PARAM(unsigned, address));

enum flash_set_write_disable_result
  flash_set_write_disable(void);

bool flash_verify_page(unsigned address, const char page[]);

enum flash_write_page_async_result
  flash_write_page_async(unsigned address, const char page[]);

int flash_get_data_partition_base(void);

int flash_get_page_size(void);

int flash_get_size(void);

#endif
