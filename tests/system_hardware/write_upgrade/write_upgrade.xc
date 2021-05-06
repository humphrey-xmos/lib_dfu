// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
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

void write_begin(int boot_address, int data_address)
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

FILE * movable write(FILE * movable bin_file,
                     int &upgrade_size, int block_size, int marker)
{
  struct dfu_getstatus ret;
  enum dfu_state state;
  size_t read;
  char block[DFU_BLOCK_SIZE_MAX_BYTES];
  int block_count = 0;

  while (!feof(bin_file)) {
    printintln(block_count);

    read = fread(block, 1, block_size, bin_file);
    assert(read >= 0 && read <= block_size);

    if (read == 0)
      break;

    dfu_dnload(marker | block_count, read, block);

    do {
      ret = dfu_getstatus();
      assert(ret.status == DFU_OK);
      delay_microseconds(1);
    } while (ret.state == DFU_DNBUSY);

    assert(ret.state == DFU_DNLOAD_IDLE);

    block_count++;
  }

  dfu_dnload(0, 0, block);
  state = dfu_getstate();
  assert(state == DFU_MANIFEST_SYNC);

  do {
    ret = dfu_getstatus();
    assert(ret.status == DFU_OK);
    delay_microseconds(1);
  } while (ret.state == DFU_DNBUSY);

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
  assert(argc == 6);

  FILE * movable boot_file = fopen((char*)argv[1], "rb");
  FILE * movable data_file = fopen((char*)argv[2], "rb");
  int block_size = 0;
  int boot_address = 0;
  int data_address = 0;
  unsafe {
    sscanf(argv[3], "%d", &block_size);
    sscanf(argv[4], "%d", &boot_address);
    sscanf(argv[5], "%d", &data_address);
  }

  int boot_size = 0;
  int data_size = 0;

  write_begin(boot_address, data_address);

  boot_file = write(move(boot_file), boot_size, block_size, 0);
  printf("written %d boot bytes\n", boot_size);

  data_file = write(move(data_file), data_size, block_size,
                    DFU_BLOCK_NUM_DATA_IMAGE_MARKER);
  printf("written %d data bytes\n", data_size);

  fseek(boot_file, 0, SEEK_SET);
  fseek(data_file, 0, SEEK_SET);

  boot_file = verify(move(boot_file), block_size, boot_address);
  printf("boot verified\n");

  data_file = verify(move(data_file), block_size, data_address);
  printf("data verified\n");

  fclose(move(boot_file));
  fclose(move(data_file));

  fl_disconnect();

  printstr("PASS\n");
  return 0;
}
