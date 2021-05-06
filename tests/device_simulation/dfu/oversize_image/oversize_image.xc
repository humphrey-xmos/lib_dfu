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

#define UPGRADE_IMAGE_SIZE 262144

struct {
  struct {
    unsigned base;
    unsigned u_start;
    unsigned u_size;
  } partitions[2];
  int busy_countdown;
  char sector_erased[512];  // use 8bit char instead of 32bit bool
  char page_written[8192];
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

int flash_get_data_partition_base(void)
{
  return 1048576;
}

int flash_get_size(void)
{
  return 2097152;
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
  fl.sector_erased[address / 4096] = (char)true;
  fl.busy_countdown = 5;

  return 0;
}

bool flash_is_sector_erased(unsigned address)
{
  return fl.sector_erased[address / 4096];
}

enum flash_write_page_async_result
  flash_write_page_async(unsigned address, const char page[])
{
  debug_printf("flash_write_page_async\n");

  assert(fl.busy_countdown == 0);
  assert(fl.sector_erased[address / 4096]);
  fl.page_written[address / 256] = (char)true;
  fl.busy_countdown = 1;

  return 0;
}

bool flash_verify_page(unsigned address, const char page[])
{
  debug_printf("flash_verify_page 0x%X\n", address);
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

void layout_flash(int block_size, int block_count)
{
  debug_printf("image blocks %d x %d bytes\n", block_count, block_size);

  fl.partitions[0].base = 0;
  fl.partitions[1].base = 1048576;

  for (int p = 0; p < 2; p++) {
    fl.partitions[p].u_start = fl.partitions[p].base + 8192;
    fl.partitions[p].u_size = block_count * block_size;
    debug_printf("%s partition: base %d, upgrade 0x%X (%d)\n",
                 labels[p], fl.partitions[p].base,
                 fl.partitions[p].u_start, fl.partitions[p].u_size);
  }

  fl.busy_countdown = 0;
  memset(fl.sector_erased, 0, sizeof(fl.sector_erased));
  memset(fl.page_written, 0, sizeof(fl.page_written));
}

static enum dfu_status
  single_dnload_block(int block_num, size_t block_size, const char block[])
{
  struct dfu_getstatus ret;
  enum dfu_state state;

  dfu_dnload(block_num, block_size, block);
  state = dfu_getstate();
  assert(state == DFU_DNLOAD_SYNC);

  do {
    ret = dfu_getstatus();
    if (ret.status != DFU_OK)
      return ret.status;

    delay_microseconds(1);
  } while (ret.state == DFU_DNBUSY);

  assert(ret.state == DFU_DNLOAD_IDLE);

  return DFU_OK;
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

void verify(void)
{
  for (int p = 0; p < 2; p++) {
    debug_printf("verify %d (protect %d..%d)\n", p, fl.partitions[p].base,
                 fl.partitions[p].u_start);
    debug_printf("sector erased:");
    for (int s = 0; s < 512; s++) {
      debug_printf(" %d", fl.sector_erased[s]);
      /*if (s * 4096 >= fl.partitions[p].u_start)
        debug_printf(" %d", s * 4096);*/

      if (s * 4096 >= fl.partitions[p].base &&
          (s + 1) * 4096 <= fl.partitions[p].u_start)
        assert(!fl.sector_erased[s]);
    }
    debug_printf("\npage written:");
    for (int i = 0; i < 8192; i++) {
      debug_printf(" %d", fl.page_written[i]);

      if (i * 256 >= fl.partitions[p].base &&
          (i + 1) * 256 <= fl.partitions[p].u_start)
        assert(!fl.page_written[i]);
    }
    debug_printf("\n");
  }
}

void dnload(int partitions, int block_size, int block_count)
{
  enum dfu_state state;
  enum dfu_status status;
  char block[DFU_BLOCK_SIZE_MAX_BYTES] = {0};

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

  for (int p = 0; p < 2; p++) {
    if (partitions & (1 << p)) {
      const unsigned marker = DFU_BLOCK_NUM_DATA_IMAGE_MARKER * p;
      for (int i = 0; i < block_count; i++) {
        debug_printf("dnload block %d 0x%04X (%d bytes)\n",
                     i, marker | i, block_size);

        status = single_dnload_block(marker | i, block_size, block);
        if (status != DFU_OK) {
          assert(status == ERR_ADDRESS);
          dfu_clrstatus();
          state = dfu_getstate();
          assert(state == DFU_IDLE);
          break;
        }
      }
      state = dfu_getstate();
      if (state == DFU_DNLOAD_IDLE) { // DNLOAD-IDLE state indicates no error
        debug_printf("dnload zero\n");
        dnload_zero();
      }
    }
  }
}

int main(unsigned argc, char * unsafe argv[argc])
{
  const int block_size = 128;
  const int normal_image = 32768;
  const int oversize_image = 1048576;
  int partitions = 0;

  assert(argc == 2);

  unsafe {
    sscanf(argv[1], "%d", &partitions);
  }

  layout_flash(block_size, normal_image / block_size);

  dnload(partitions, block_size, oversize_image / block_size);

  verify();

  printstr("PASS\n");
  return 0;
}
