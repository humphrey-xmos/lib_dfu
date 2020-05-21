// Copyright (c) 2019-2020, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include <stdio.h>
#include <stddef.h>
#include <print.h>
#include <string.h>
#include <quadflash.h>
#include <quadflashlib.h>

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

#include "quadflash_extra.h"
#include "dfu.h"

fl_QSPIPorts ports = {
  PORT_SQI_CS, PORT_SQI_SCLK, PORT_SQI_SIO, XS1_CLKBLK_1
};

fl_QuadDeviceSpec spec = { // IS25LQ016B
  0, 256, 8192, 3, 8, 0x9F, 0, 3, 0x9D4015, 0x20, 4096, 0x06, 0x04,
  PROT_TYPE_NONE, {{0,0},{0x00,0x00}}, 0x02, 0xEB, 1,
  SECTOR_LAYOUT_REGULAR, {4096,{0,{0}}}, 0x05, 0x01, 0x01
};

void write_begin(int upgrade_address)
{
  enum dfu_state state;
  int ret;

  ret = fl_connectToOneDevice(ports, spec);
  assert(ret == 0);

  dfu_locate_upgrade_slots();
  fl_disconnect();

  state = dfu_getstate();
  assert(state == APP_IDLE);

  dfu_detach();
  state = dfu_getstate();
  assert(state == APP_DETACH);

  ret = fl_connectToOneDevice(ports, spec);
  assert(ret == 0);

  dfu_bus_reset();
  state = dfu_getstate();
  assert(state == DFU_IDLE);
}

FILE * movable write(FILE * movable bin_file, int block_size,
                     int &upgrade_size)
{
  struct dfu_getstatus ret;
  int block_count = 0;
  size_t read;
  char block[DFU_BLOCK_SIZE_MAX_BYTES];

  while (!feof(bin_file)) {
    printintln(block_count);

    read = fread(block, 1, block_size, bin_file);
    assert(read >= 0 && read <= block_size);

    if (read == 0)
      break;

    dfu_dnload(DFU_BLOCK_NUM_DATA_IMAGE_MARKER | block_count, read, block);

    do {
      ret = dfu_getstatus();
      assert(ret.status == DFU_OK);
      delay_microseconds(1);
    } while (ret.state == DFU_DNBUSY);

    assert(ret.state == DFU_DNLOAD_IDLE);

    block_count++;
  }

  dfu_dnload(0, 0, block);
  ret.state = dfu_getstate();
  assert(ret.state == DFU_MANIFEST_SYNC);

  ret = dfu_getstatus();
  assert(ret.state == DFU_IDLE);
  assert(ret.status == DFU_OK);

  upgrade_size = block_count * block_size;

  return move(bin_file);
}

FILE * movable verify(FILE * movable bin_file, int block_size,
                      unsigned upgrade_address)
{
  int page_count = 0;
  unsigned addr = upgrade_address;
  size_t ret;
  char expected[256], actual[256];

  while (!feof(bin_file)) {
    printintln(page_count);

    ret = fread(expected, 1, sizeof(expected), bin_file);
    assert(ret >= 0 && ret <= sizeof(expected));

    if (ret == 0)
      break;

    fl_readPage(addr, actual);
    addr += ret;

    ret = memcmp(expected, actual, ret);
    assert(ret == 0);

    page_count++;
  }

  return move(bin_file);
}

int main(unsigned argc, char * unsafe argv[argc])
{
  assert(argc == 4);

  FILE * movable bin_file = fopen((char*)argv[1], "rb");
  int block_size = 0;
  int upgrade_address = 0;
  unsafe {
    sscanf(argv[2], "%d", &block_size);
    sscanf(argv[3], "%d", &upgrade_address);
  }

  write_begin(upgrade_address);

  int upgrade_size = 0;
  bin_file = write(move(bin_file), block_size, upgrade_size);
  printf("written %d bytes\n", upgrade_size);

  fseek(bin_file, 0, SEEK_SET);

  printf("upgrade address 0x%X\n", upgrade_address);
  bin_file = verify(move(bin_file), block_size, upgrade_address);
  printf("verified\n");

  fclose(move(bin_file));

  fl_disconnect();

  printstr("PASS\n");
  return 0;
}
