// Copyright 2019-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "dfu_flash.h"

#if (DFU_QUAD_SPI_FLASH)
#include <quadflashlib.h>
#else
#include <flashlib.h>
#endif

#include <stdint.h>

#include "dfu.h"
#if defined (DFU_ENABLE) && (DFU_ENABLE == 1)

struct flash_session {
  int32_t device_open;
  fl_BootImageInfo factory_image;
  fl_BootImageInfo upgrade_image;

  int32_t upgrade_image_valid;
};

static struct flash_session session;

enum flash_status flash_init(void) {
  fl_BootImageInfo image;

  if (!session.device_open) {
    if (flash_enable_ports() == DFU_FLASH_OK) {
      session.device_open = 1;
    }
  }

  if (!session.device_open) {
    return DFU_FLASH_OPEN_ERROR;
  }

#if defined(DFU_QUAD_SPI_FLASH) && (DFU_QUAD_SPI_FLASH == 0)
  // Disable flash protection
  fl_setProtection(0);
#endif

  if (fl_getFactoryImage(&image) != 0) {
    return DFU_FLASH_GET_FACTORY_IMAGE_FAILED;
  }

  session.factory_image = image;

  if (fl_getNextBootImage(&image) == 0) {
    session.upgrade_image_valid = 1;
    session.upgrade_image = image;
  }

  return DFU_FLASH_OK;
}

enum flash_status flash_deinit(void) {
  if (session.device_open) {
    flash_disable_ports();
    session.device_open = 0;
  }
  return DFU_FLASH_OK;
}

int32_t flash_is_connected(void) {
  return session.device_open;
}

struct flash_data_status flash_get_image_size_from_buffer(const uint8_t buf[], int32_t length)
{
  struct flash_data_status result = { DFU_FLASH_BAD_PARAM, 0 };

  // Only use fl_getPageSize() if flash is open/connected, otherwise return bad param as we can't validate the buffer size without flash connection
  if (buf == NULL || length != (session.device_open ? (int32_t)fl_getPageSize() : DFU_FLASH_PAGE_SIZE_BYTES)) {
    return result;
  }

  fl_BootImageInfo image_info;
  int ret = fl_getImageInfo(&image_info, buf);
  if (ret != 0) {
    result.status = DFU_FLASH_READ_NO_IMAGE;
    return result;
  } else {
    result.status = DFU_FLASH_OK;
    result.data = (int32_t)image_info.size;
    return result;
  }
}

enum flash_status flash_erase_sector_async(int32_t erase_size) {

  int ret = 0;
   if (erase_size <= 0) {
    return DFU_FLASH_BAD_PARAM;
  }

  if (session.upgrade_image_valid) {
    ret = fl_startImageReplace(&session.upgrade_image, (unsigned)erase_size);
  } else {
    ret = fl_startImageAdd(&session.factory_image, (unsigned)erase_size, 0);
  }
  if (ret < 0) {
    return DFU_FLASH_ERASE_ERROR;
  } else if (ret > 0) {
    return DFU_FLASH_BUSY;
  } else {
    session.upgrade_image_valid = 0;
    return DFU_FLASH_OK;
  }
}

enum flash_status flash_write_page(const uint8_t page[], int32_t length) {
  if (page == NULL || length != (int32_t)fl_getPageSize()) {
    return DFU_FLASH_BAD_PARAM;

  } else if (session.upgrade_image_valid) {
    return DFU_FLASH_ERASE_ERROR;

  } else if (fl_writeImagePage(page) != 0) {
    return DFU_FLASH_WRITE_ERROR;
  }
  return DFU_FLASH_OK;
}

enum flash_status flash_finalise_write() {
  if (fl_endWriteImage() != 0) {
    return DFU_FLASH_WRITE_ERROR;
  }

  // Sanity check
  fl_BootImageInfo image = session.factory_image;
  if (fl_getNextBootImage(&image) != 0) {
    return DFU_FLASH_OPEN_ERROR;
  }
  session.upgrade_image = image;
  session.upgrade_image_valid = 1;
  return DFU_FLASH_OK;
}

struct flash_data_status flash_start_read() {
  struct flash_data_status result = { DFU_FLASH_READ_ERROR, 0 };

  if (!session.upgrade_image_valid) {
    result.status = DFU_FLASH_READ_NO_IMAGE;
    return result;

  } else {
    int read = fl_startImageRead(&session.upgrade_image);
    if (read != 0) {
      result.status = DFU_FLASH_READ_ERROR;
      return result;
    } else {
      result.status = DFU_FLASH_OK;
      result.data = (int32_t)session.upgrade_image.size;
      return result;
    }
  }
}

enum flash_status flash_read_page(uint8_t data[], int32_t length) {
  if (data == NULL || length != (int32_t)fl_getPageSize()) {
    return DFU_FLASH_BAD_PARAM;

  } else if (!session.upgrade_image_valid) {
    return DFU_FLASH_READ_NO_IMAGE;
  }

  if (fl_readImagePage(data) != 0) {
    return DFU_FLASH_READ_ERROR;
  }
  return DFU_FLASH_OK;
}

int32_t flash_is_busy(void) { return (fl_getBusyStatus() != 0); }

int32_t flash_get_page_size(void) { return (int32_t)fl_getPageSize(); }

int32_t flash_get_sector_size(void) { return (int32_t)fl_getSectorSize(0); }

int32_t flash_get_size(void) { return (int32_t)fl_getFlashSize(); }

int32_t flash_is_suitable(void)
{
  if (flash_get_page_size() > DFU_FLASH_PAGE_SIZE_BYTES) {
    return 0;
  }

  return 1;
}

#endif
