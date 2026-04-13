// Copyright 2019-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <platform.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <unity.h>
#include <xclib.h>
#include <xs1.h>

#define DEBUG_UNIT TEST
#define DEBUG_PRINT_ENABLE_TEST 1
#include "debug_print.h"
#include "dfu.h"
#include "dfu_flash.h"


// See lib.xc for crc32 implementation
void crc32_c(unsigned *checksum, unsigned data, unsigned poly);

#define MAX_IMAGE_SIZE 20480

struct {
  int state_erasing;
  unsigned erase_size;
  int state_writing;
  int flash_open;
  int address;
  struct {
    int base;
    int f_start;
    int f_size;
    int u_start;
    int u_size;
    char u_contents[MAX_IMAGE_SIZE];
  } partitions;
  int busy_countdown;
  char page_erased[8192];    // use 8bit char instead of 32bit bool
  char page_verified[8192];  // 32bit would make data region offset overrun
} fl;

const char *labels = "boot";

enum flash_status flash_init() {
  fl.flash_open = 1;
  return DFU_FLASH_OK;
}

enum flash_status flash_deinit() {
  fl.flash_open = 0;
  return DFU_FLASH_OK;
}

int32_t flash_is_connected(void) {
  return fl.flash_open;
}

enum flash_status flash_erase_sector_async(int32_t erase_size) {
  (void)erase_size;

  if (!fl.state_erasing) {
    TEST_ASSERT_FALSE(fl.state_writing);
    fl.state_erasing = 1;
    /* Overriding erase size during test */
    fl.erase_size = MAX_IMAGE_SIZE;
    fl.address = fl.partitions.u_start;

  } else {
    if (fl.address >= fl.partitions.u_start + fl.partitions.u_size) {
      fl.state_erasing = 0;
      return DFU_FLASH_OK;
    }
  }
  debug_printf("flash_erase_sector_async 0x%X\n", fl.address);
  
  TEST_ASSERT_EQUAL(0, fl.busy_countdown);

  for (int i = 0; i < (4096 / 256); i++) {
    int page_address = fl.address + 256 * i;
    int page_index = fl.address / 256 + i;

    fl.page_erased[page_index] = 1;

    if (page_address >= fl.partitions.u_start &&
        page_address < fl.partitions.u_start + fl.partitions.u_size) {

      int contents_offset = fl.address - fl.partitions.u_start + 256 * i;
      debug_printf("erase %s upgrade offset 0x%X (flash page %d)\n",
                    labels, contents_offset, page_index);

      memset(&fl.partitions.u_contents[contents_offset], 0xFF, 256);
    }
  }
  fl.busy_countdown = 0;

  if (fl.state_erasing) {
    fl.address += 4096;
  }

  return DFU_FLASH_BUSY;
}

enum flash_status flash_write_page(const uint8_t page[], int32_t length) {
  debug_printf("flash_write_page_async\n");
  if (length != 256) {
    return DFU_FLASH_BAD_PARAM;
  }
  if (!fl.state_writing) {
    TEST_ASSERT_FALSE(fl.state_erasing);
    fl.state_writing = 1;
    fl.address = fl.partitions.u_start;
  }

  TEST_ASSERT_EQUAL(0, fl.busy_countdown);

  if (!fl.page_erased[fl.address / 256]) {
    debug_printf("page not erased 0x%X\n", fl.address);
    return DFU_FLASH_ERASE_ERROR;
  }

  if (fl.address >= fl.partitions.u_start && fl.address < fl.partitions.u_start + fl.partitions.u_size) {
    int contents_offset = fl.address - fl.partitions.u_start;
    debug_printf("write %s upgrade offset 0x%X (flash page %d) %02X\n", labels, contents_offset, fl.address / 256,
                 page[0]);

    memcpy(&fl.partitions.u_contents[contents_offset], page, 256);
  }

  // Flash library write performs verification for us.
  debug_printf("flash_verify_page 0x%X\n", fl.address);
  fl.page_verified[fl.address / 256] = 1;

  fl.busy_countdown = 0;

  if (fl.state_writing) {
    fl.address += 256;
  }
  return DFU_FLASH_OK;
}

enum flash_status flash_finalise_write() {
  fl.address = 0;
  fl.state_writing = 0;
  return DFU_FLASH_OK;
}

int32_t flash_is_busy(void) {
  if (fl.busy_countdown > 0) {
    debug_printf("busy countdown %d\n", fl.busy_countdown);
    fl.busy_countdown--;
    return 1;
  } else {
    return 0;
  }
}

void layout_flash(int block_count, int block_size, int tail_size) {
  debug_printf("image blocks %d x %d bytes + %d bytes tail\n", block_count, block_size, tail_size);

  fl.state_erasing = 0;
  fl.erase_size = 0;
  fl.state_writing = 0;
  fl.address = 0;
  fl.partitions.base = 0;
  fl.flash_open = 0;

  fl.partitions.f_start = fl.partitions.base + 4096;
  fl.partitions.f_size = 256;
  fl.partitions.u_start = fl.partitions.f_start + 4096;
  fl.partitions.u_size = (block_count * block_size) + tail_size;
  memset(fl.partitions.u_contents, 0, MAX_IMAGE_SIZE);

  debug_printf("%s partition: factory 0x%X (%d), upgrade 0x%X (%d)\n", labels, fl.partitions.f_start,
               fl.partitions.f_size, fl.partitions.u_start, fl.partitions.u_size);

  fl.busy_countdown = 0;

  memset(fl.page_erased, 0, sizeof(fl.page_erased));
  memset(fl.page_verified, 0, sizeof(fl.page_verified));
}

void make_test_data(uint8_t seq[], int32_t length) {
  // memset(seq, 33, (size_t)length);
  for (int32_t i = 0; i < length; i++) {
    unsigned x;
    crc32_c(&x, (unsigned)-1, 0xEB31D82EU);
    seq[i] = (uint8_t)x;
  }
}

static uint8_t payload[DFU_TRANSFER_SIZE_BYTES];

static void get_state_and_check(enum dfu_state expected_state)
{
  struct dfu_cmd_response response = dfu_request_with_arguments(DFU_GETSTATE, payload, DFU_GET_STATE_PAYLOAD_SIZE_BYTES, NULL);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  TEST_ASSERT_EQUAL(expected_state, payload[0]);
}

static struct dfu_getstatus get_status(enum dfu_cmd_request *deferred_request)
{
  struct dfu_cmd_response response = dfu_request_with_arguments(DFU_GETSTATUS, payload, DFU_GET_STATUS_PAYLOAD_SIZE_BYTES, NULL);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);

  if (response.deferred_request != 0 && deferred_request != NULL) {
    *deferred_request = response.deferred_request;
  }

  struct dfu_getstatus ret = { .status = payload[DFU_GETSTATUS_STATUS_INDEX], .state = payload[DFU_GETSTATUS_STATE_INDEX] };
  return ret;
}

static void single_dnload_block(int32_t block_num, int32_t block_size, const uint8_t block[]) {
  struct dfu_getstatus ret;

  struct dfu_cmd_response response = dfu_request_with_arguments(DFU_DNLOAD, (uint8_t *)block, block_size, &block_num);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_DFU_DOWNLOAD_SYNC);

  do {
    enum dfu_cmd_request deferred_request = 0;
    ret = get_status(&deferred_request);
    TEST_ASSERT_EQUAL(DFU_OK, ret.status);

    if (deferred_request && (deferred_request != DFU_DEFERRED_ACTION_REBOOT) && (deferred_request != DFU_DEFERRED_ACTION_REBOOT_TO_DFU)) {
      struct dfu_cmd_response deferred_status = dfu_request(deferred_request);
      if (DFU_API_SUCCESS != deferred_status.status) {
        struct dfu_getstatus err = get_status(&deferred_request);
        TEST_ASSERT_EQUAL_UINT8(STATE_DFU_ERROR, err.state);
        TEST_ASSERT_EQUAL_UINT8(DFU_OK, err.status);
      }
    }
    delay_microseconds(1);
  } while (ret.state == STATE_DFU_DOWNLOAD_BUSY);

  TEST_ASSERT_EQUAL(STATE_DFU_DOWNLOAD_IDLE, ret.state);
}

static void dnload_zero(void) {
  struct dfu_getstatus ret;
  uint8_t block[DFU_TRANSFER_SIZE_BYTES];

  struct dfu_cmd_response response = dfu_request_with_arguments(DFU_DNLOAD, block, 0, NULL);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_DFU_MANIFEST_SYNC);

  do {
    enum dfu_cmd_request deferred_request = 0;
    ret = get_status(&deferred_request);
    TEST_ASSERT_EQUAL(DFU_OK, ret.status);
    
    if (deferred_request && (deferred_request != DFU_DEFERRED_ACTION_REBOOT) && (deferred_request != DFU_DEFERRED_ACTION_REBOOT_TO_DFU)) {
      struct dfu_cmd_response deferred_status = dfu_request(deferred_request);
      if (DFU_API_SUCCESS != deferred_status.status) {
        struct dfu_getstatus err = get_status(&deferred_request);
        TEST_ASSERT_EQUAL_UINT8(STATE_DFU_ERROR, err.state);
        TEST_ASSERT_EQUAL_UINT8(DFU_OK, err.status);
      }
    }
    delay_microseconds(1);
  } while (ret.state != STATE_DFU_IDLE);

  TEST_ASSERT_EQUAL(STATE_DFU_IDLE, ret.state);
  TEST_ASSERT_EQUAL(DFU_OK, ret.status);
}

static void bus_reset() {
  struct dfu_cmd_response response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  if (response.deferred_request == DFU_DEFERRED_ACTION_FLASH_CONNECT) {
    response = dfu_request(response.deferred_request);
    TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  }
}

static void detach() {
  get_state_and_check(STATE_APP_IDLE);

  dfu_request(DFU_DETACH);
  get_state_and_check(STATE_APP_DETACH);

  bus_reset();
  get_state_and_check(STATE_DFU_IDLE);
}

static void reboot() {
  get_state_and_check(STATE_DFU_IDLE);

  bus_reset();
  get_state_and_check(STATE_APP_IDLE);
}

void dnload(const uint8_t images[MAX_IMAGE_SIZE], int32_t block_size, int32_t block_count, int32_t tail_size, int32_t repeats) {
  for (int32_t r = 0; r < repeats; r++) {
    const int32_t marker = 0;  // Was, DFU_BLOCK_NUM_DATA_IMAGE_MARKER * p;
    for (int32_t i = 0; i < block_count; i++) {
      debug_printf("dnload block %d 0x%04X (%d bytes)\n", i, marker | (int32_t)i, block_size);

      single_dnload_block((marker | i), block_size, &images[i * block_size]);
    }
    if (tail_size > 0) {
      debug_printf("dnload block %d 0x%04X (tail %d bytes)\n", block_count, marker | block_count, tail_size);

      single_dnload_block((marker | block_count), tail_size, &images[block_count * block_size]);
    }
    TEST_ASSERT_TRUE(fl.flash_open);
    debug_printf("dnload zero\n");
    dnload_zero();

    /* Sanity checks */
    TEST_ASSERT_FALSE(fl.state_erasing);
    TEST_ASSERT_FALSE(fl.state_writing);
    TEST_ASSERT_TRUE(fl.flash_open);
    
    if (r != (repeats - 1)) {
      memset(fl.page_erased, 0, sizeof(fl.page_erased));
      memset(fl.page_verified, 0, sizeof(fl.page_verified));
    }
  }
}

void verify(const uint8_t images[MAX_IMAGE_SIZE], size_t length) {
  debug_printf("verify\n");

  int cmp = memcmp(fl.partitions.u_contents, images, length);
  TEST_ASSERT_EQUAL(0, cmp);

  /* Page-by-page verification */
  for (size_t i = 0; i < length; i += 256) {
    int address = fl.partitions.u_start + i;
    if (!fl.page_verified[address / 256]) {
      debug_printf("page not verified 0x%X\n", address);
    }
    TEST_ASSERT_TRUE(fl.page_verified[address / 256]);
  }
}

uint8_t images[MAX_IMAGE_SIZE];

void test_dnload(void) {
  int block_size = 0;
  int block_count = 0;
  int tail_size = 0;
  int repeats = 0;

  block_size = 64;  // bytes
  block_count = 64; // blocks
  tail_size = 63;   // bytes, ideally less than block_size
  repeats = 2;

  layout_flash(block_count, block_size, tail_size);

  make_test_data(images, fl.partitions.u_size);

  detach();
  dnload((const uint8_t *)images, block_size, block_count, tail_size, repeats);

  verify((const uint8_t *)images, fl.partitions.u_size);
  
  reboot();
  
  TEST_ASSERT_FALSE(fl.flash_open);
}

void test_dnload_no_tail(void) {
  int block_size = 0;
  int block_count = 0;
  int tail_size = 0;
  int repeats = 0;

  block_size = 64;  // bytes
  block_count = 64; // blocks
  tail_size = 0;   // bytes, ideally less than block_size
  repeats = 2;

  layout_flash(block_count, block_size, tail_size);

  make_test_data(images, fl.partitions.u_size);

  detach();
  dnload((const uint8_t *)images, block_size, block_count, tail_size, repeats);

  verify((const uint8_t *)images, fl.partitions.u_size);
  
  reboot();
  
  TEST_ASSERT_FALSE(fl.flash_open);
}

void test_dnload_write_less_than_one_page(void) {
  int block_size = 0;
  int block_count = 0;
  int tail_size = 0;
  int repeats = 0;

  block_size = 64;  // bytes
  block_count = 1; // blocks
  tail_size = 0;   // bytes, ideally less than block_size
  repeats = 2;

  layout_flash(((3 * 4096) / block_size), block_size, tail_size);

  make_test_data(images, fl.partitions.u_size);

  detach();
  dnload((const uint8_t *)images, block_size, block_count, tail_size, repeats);

  verify((const uint8_t *)images, (size_t)((block_size * block_count) + tail_size));
  
  reboot();
  
  TEST_ASSERT_FALSE(fl.flash_open);
}
