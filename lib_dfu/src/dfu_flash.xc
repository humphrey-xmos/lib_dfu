// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef DFU_FLASH_UNIT_TEST
#include <safestring.h>
#include <quadflash.h>
#include <quadflashlib.h>
#include "quadflash_extra.h"
#include "dfu_types.h"
#include "dfu_flash.h"
#include "dfu_flash_result.h"

enum flash_locate_boot_upgrade_slot_result
  flash_locate_boot_upgrade_slot(unsigned &address)
{
  fl_BootImageInfo info;

  if (fl_getFactoryImage(info) != 0)
    return FLASH_LOCATE_BOOT_UPGRADE_SLOT_GET_FACTORY_IMAGE_FAILED;

  // rounding up to whole sectors as per fl_initImageWriteState
  if (fl_getNextBootImage(info) == 0)
    address = info.startAddress;
  else
    address = fl_roundAddressUpToWholeSector(info.startAddress + info.size);

  return FLASH_LOCATE_BOOT_UPGRADE_SLOT_SUCCESS;
}

enum flash_locate_data_upgrade_slot_result
  flash_locate_data_upgrade_slot(unsigned &address)
{
  fl_DataImageInfo info;

  if (fl_getFactoryDataImageNoChecksum(info) != 0)
    return FLASH_LOCATE_DATA_UPGRADE_SLOT_GET_FACTORY_DATA_IMAGE_NO_CHECKSUM_FAILED;

  if (fl_getNextDataImageNoChecksum(info) == 0)
    address = info.startAddress;
  else
    address = fl_roundAddressUpToWholeSector(info.startAddress + info.size);

  return FLASH_LOCATE_DATA_UPGRADE_SLOT_SUCCESS;
}

enum flash_erase_sector_async_result
  flash_erase_sector_async(unsigned address)
{
  // protect first sector of boot partition
  if (address >= fl_getSectorAddress(0) && address < fl_getSectorEndAddress(0))
    return FLASH_ERASE_SECTOR_ASYNC_IN_FIRST_BOOT_SECTOR;

  // protect first sector of data partition
  if (address >= fl_getDataPartitionBase() &&
      address < fl_getSectorEndAddress(fl_getSectorContaining(fl_getDataPartitionBase())))
    return FLASH_ERASE_SECTOR_ASYNC_IN_FIRST_DATA_SECTOR;

  // disallow wrap-around flash address in order to protect boot partition
  if (address >= fl_getFlashSize())
    return FLASH_ERASE_SECTOR_ASYNC_OUTSIDE_FLASH_LIMITS;

  if (fl_setWritability(1) != 0)
    return FLASH_ERASE_SECTOR_ASYNC_SET_WRITABILITY_FAILED;

  unsafe {
    fl_int_eraseSector(g_flashAccess->sectorEraseCommand, address);
  }

  return FLASH_ERASE_SECTOR_ASYNC_SUCCESS;
}

bool flash_is_busy(void)
{
  return fl_getBusyStatus() != 0;
}

bool flash_is_first_whole_page_in_sector(unsigned address)
{
  int page_size = fl_getPageSize();

  if (address < page_size)
    return true;

  return fl_getSectorContaining(address - page_size) !=
         fl_getSectorContaining(address);
}

bool flash_is_sector_erased(unsigned address)
{
  unsigned page_address = address;
  int page_size = fl_getPageSize();
  while (fl_getSectorContaining(page_address) == fl_getSectorAtOrAfter(address)) {
    char page[DFU_PAGE_SIZE_MAX_BYTES];
    fl_readPage(page_address, page);
    for (int i = 0; i < page_size; i++) {
      if (page[i] != 0xFF)
        return false;
    }
    page_address += page_size;
  }
  return true;
}

enum flash_set_write_disable_result
  flash_set_write_disable(void)
{
  if (fl_setWritability(0) == 0)
    return FLASH_SET_WRITE_DISABLE_SUCCESS;
  else
    return FLASH_SET_WRITE_DISABLE_ERROR;
}

enum flash_write_page_async_result
  flash_write_page_async(unsigned address, const char page[])
{
  int page_size = fl_getPageSize();

  // protect first sector of boot partition
  if (address >= fl_getSectorAddress(0) && address < fl_getSectorEndAddress(0))
    return FLASH_WRITE_PAGE_ASYNC_IN_FIRST_BOOT_SECTOR;

  // protect first sector of data partition
  if (address >= fl_getDataPartitionBase() &&
      address < fl_getSectorEndAddress(fl_getSectorContaining(fl_getDataPartitionBase())))
    return FLASH_WRITE_PAGE_ASYNC_IN_FIRST_DATA_SECTOR;

  // disallow wrap-around flash address in order to protect boot partition
  if (address >= fl_getFlashSize())
    return FLASH_WRITE_PAGE_ASYNC_OUTSIDE_FLASH_LIMITS;

  if (fl_setWritability(1) != 0)
    return FLASH_WRITE_PAGE_ASYNC_SET_WRITABILITY_FAILED;

  unsafe {
    fl_int_write(g_flashAccess->programPageCommand, address, page, page_size);
  }

  return FLASH_WRITE_PAGE_ASYNC_SUCCESS;
}

bool flash_verify_page(unsigned address, const char page[])
{
  int page_size = fl_getPageSize();
  char verify[DFU_PAGE_SIZE_MAX_BYTES];

  fl_readPage(address, verify);
  return safememcmp(verify, page, page_size) == 0;
}

int flash_get_data_partition_base(void)
{
  return fl_getDataPartitionBase();
}

int flash_get_page_size(void)
{
  return fl_getPageSize();
}

int flash_get_size(void)
{
  return fl_getFlashSize();
}

#endif
