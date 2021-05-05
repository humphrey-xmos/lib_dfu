// Copyright 2019-2021 XMOS LIMITED.
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

#define MAX_IMAGE_SIZE 20480

struct {
  struct {
    unsigned base;
    unsigned f_start;
    unsigned f_size;
    unsigned u_start;
    unsigned u_size;
    char u_contents[MAX_IMAGE_SIZE];
  } partitions[2];
  int busy_countdown;
  char page_erased[8192];   // use 8bit char instead of 32bit bool
  char page_verified[8192]; // 32bit would make data region offset overrun
} fl;

const char labels[2][5] = {"boot", "data"};

enum flash_set_write_disable_result
  flash_set_write_disable(void)
{
  return 0; // no checking of write enable
}

int flash_get_page_size(void)
{
  return 256;
}

int flash_get_size(void)
{
  return 2097152;
}

int flash_get_data_partition_base(void)
{
  return 1048576;
}

bool flash_is_first_whole_page_in_sector(unsigned address)
{
  if (address < 256)
    return true;

  debug_printf("is %d first whole page in sector: %d\n", address,
               (address - 256) / 4096 != address / 4096);

  return (address - 256) / 4096 != address / 4096;
}

enum flash_erase_sector_async_result
  flash_erase_sector_async(unsigned address)
{
  debug_printf("flash_erase_sector_async 0x%X\n", address);

  assert(fl.busy_countdown == 0);

  for (int i = 0; i < 16; i++) {
    int page_address = address + 256 * i;
    int page_index = address / 256 + i;

    for (int p = 0; p < 2; p++) {
      if (page_address >= fl.partitions[p].u_start &&
          page_address < fl.partitions[p].u_start + fl.partitions[p].u_size) {

        int contents_offset = address - fl.partitions[p].u_start + 256 * i;
        debug_printf("erase %s upgrade offset 0x%X (flash page %d)\n",
                     labels[p], contents_offset, page_index);

        memset(&fl.partitions[p].u_contents[contents_offset], 0xFF, 256);
      }
    }
    fl.page_erased[page_index] = (char)true;
  }
  fl.busy_countdown = 5;

  return 0;
}

bool flash_is_sector_erased(unsigned address)
{
  return fl.page_erased[address / 256]; // it's ok to only look at first page
}

enum flash_write_page_async_result
  flash_write_page_async(unsigned address, const char page[])
{
  debug_printf("flash_write_page_async\n");

  assert(fl.busy_countdown == 0);
  assert(fl.page_erased[address / 256]);

  for (int p = 0; p < 2; p++) {
    if (address >= fl.partitions[p].u_start &&
        address < fl.partitions[p].u_start + fl.partitions[p].u_size) {

      int contents_offset = address - fl.partitions[p].u_start;
      debug_printf("write %s upgrade offset 0x%X (flash page %d) %02X\n",
                   labels[p], contents_offset, address / 256, page[0]);

      memcpy(&fl.partitions[p].u_contents[contents_offset], page, 256);
    }
  }

  fl.busy_countdown = 1;

  return 0;
}

bool flash_verify_page(unsigned address, const char page[])
{
  debug_printf("flash_verify_page 0x%X\n", address);
  fl.page_verified[address / 256] = (char)true;
  return true; // always report success, test verification is performed later
}

bool flash_is_busy(void)
{
  if (fl.busy_countdown > 0) {
    debug_printf("busy countdown %d\n", fl.busy_countdown);
    fl.busy_countdown--;
    return true;
  }
  else {
    return false;
  }
}

enum flash_locate_boot_upgrade_slot_result
  flash_locate_boot_upgrade_slot(unsigned &address)
{
  address = fl.partitions[0].u_start;
  return 0;
}

enum flash_locate_data_upgrade_slot_result
  flash_locate_data_upgrade_slot(unsigned &address)
{
  address = fl.partitions[1].u_start;
  return 0;
}

void layout_flash(int block_count, int block_size, int tail_size)
{
  debug_printf("image blocks %d x %d bytes + %d bytes tail\n",
               block_count, block_size, tail_size);

  fl.partitions[0].base = 0;
  fl.partitions[1].base = 1048576;

  for (int p = 0; p < 2; p++) {
    fl.partitions[p].f_start = fl.partitions[p].base + 4096;
    fl.partitions[p].f_size = 256;
    fl.partitions[p].u_start = fl.partitions[p].f_start + 4096;
    fl.partitions[p].u_size = block_count * block_size + tail_size;
    memset(fl.partitions[p].u_contents, 0, MAX_IMAGE_SIZE);

    debug_printf("%s partition: factory 0x%X (%d), upgrade 0x%X (%d)\n",
                 labels[p], fl.partitions[p].f_start, fl.partitions[p].f_size,
                 fl.partitions[p].u_start, fl.partitions[p].u_size);
  }

  fl.busy_countdown = 0;

  memset(fl.page_erased, 0, sizeof(fl.page_erased));
  memset(fl.page_verified, 0, sizeof(fl.page_verified));
}

void make_test_data(char seq[], int length)
{
  for (int i = 0; i < length; i++) {
    unsigned x;
    crc32(x, -1, 0xEB31D82E);
    seq[i] = x;
  }
}

void single_dnload_block(int block_num, size_t block_size, const char block[])
{
  struct dfu_getstatus ret;
  enum dfu_state state;

  dfu_dnload(block_num, block_size, block);
  state = dfu_getstate();
  assert(state == DFU_DNLOAD_SYNC);

  do {
    ret = dfu_getstatus();
    assert(ret.status == DFU_OK);
    delay_microseconds(1);
  } while (ret.state == DFU_DNBUSY);

  assert(ret.state == DFU_DNLOAD_IDLE);
}

void dnload_zero(void)
{
  struct dfu_getstatus ret;
  enum dfu_state state;
  char block[DFU_BLOCK_SIZE_MAX_BYTES];

  dfu_dnload(0, 0, block);
  state = dfu_getstate();
  assert(state == DFU_MANIFEST_SYNC);

  do {
    ret = dfu_getstatus();
    assert(ret.status == DFU_OK);
    delay_microseconds(1);
  } while (ret.state == DFU_MANIFEST);

  assert(ret.state == DFU_IDLE);
  assert(ret.status == DFU_OK);
}

void dnload(int partitions, const char images[2][MAX_IMAGE_SIZE],
            int block_size, int block_count, int tail_size, int repeats)
{
  enum dfu_state state;

  int ret = dfu_locate_upgrade_slots();
  assert(ret == 0);

  state = dfu_getstate();
  assert(state == APP_IDLE);

  dfu_detach();
  state = dfu_getstate();
  assert(state == APP_DETACH);

  dfu_bus_reset();
  state = dfu_getstate();
  assert(state == DFU_IDLE);

  for (int i = 0; i < repeats; i++) {
    for (int p = 0; p < 2; p++) {
      if (partitions & (1 << p)) {
        const unsigned marker = DFU_BLOCK_NUM_DATA_IMAGE_MARKER * p;
        for (int i = 0; i < block_count; i++) {
          debug_printf("dnload block %d 0x%04X (%d bytes)\n",
                       i, marker | i, block_size);

          single_dnload_block(marker | i, block_size,
                              (const char*)&images[p][i * block_size]);
        }
        if (tail_size > 0) {
          debug_printf("dnload block %d 0x%04X (tail %d bytes)\n",
                       block_count, marker | block_count, tail_size);

          single_dnload_block(marker | block_count, tail_size,
                              (const char*)&images[p][block_count * block_size]);
        }
        debug_printf("dnload zero\n");
        dnload_zero();
      }
    }
  }
}

void verify(int partitions, const char images[2][MAX_IMAGE_SIZE])
{
  for (int p = 0; p < 2; p++) {
    if (partitions & (1 << p)) {
      debug_printf("verify %d\n", p);
      for (int i = 0; i < fl.partitions[p].u_size; i++) {
        int address = fl.partitions[p].u_start + i;
        if (address % 256 == 0) {
          assert(fl.page_verified[address / 256]);
        }
        if (images[p][i] != fl.partitions[p].u_contents[i]) {
          debug_printf("byte %d mismatch: 0x%02X 0x%02X\n",
                        i, images[p][i], fl.partitions[p].u_contents[i]);
          assert(0);
        }
      }
    }
  }
}

char images[2][MAX_IMAGE_SIZE];

int main(unsigned argc, char * unsafe argv[argc])
{
  int block_count = 0;
  int block_size = 0;
  int partitions = 0;
  int tail_size = 0;
  int repeats = 0;

  assert(argc == 6);

  unsafe {
    sscanf(argv[1], "%d", &block_size);
    sscanf(argv[2], "%d", &block_count);
    sscanf(argv[3], "%d", &tail_size);
    sscanf(argv[4], "%d", &partitions);
    sscanf(argv[5], "%d", &repeats);
  }

  layout_flash(block_count, block_size, tail_size);

  make_test_data(images[0], fl.partitions[0].u_size);
  make_test_data(images[1], fl.partitions[1].u_size);

  dnload(partitions, images, block_size, block_count, tail_size, repeats);

  verify(partitions, images);

  printstr("PASS\n");
  return 0;
}
