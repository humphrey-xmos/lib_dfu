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

#define DEBUG_UNIT TEST
#define DEBUG_PRINT_ENABLE_TEST 0 // requires xSCOPE
#include "debug_print.h"

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

struct {
  int start;
  int locator;
  int threshold;
} timing = {0, 0, 0};

static void t_start(int locator) {
  timer t;
  timing.locator = locator;
  t :> timing.start;
}

static void t_end(void) {
  timer t;
  int start = timing.start;
  int end;
  t :> end;
  if (end - start >= timing.threshold) {
    debug_printf("%d: %d\n", timing.locator, end - start); // requires xSCOPE
    assert(0);
  }
}

void write_begin(void)
{
  enum dfu_state state;
  int ret;

  ret = fl_connectToOneDevice(ports, spec);
  assert(ret == 0);

  dfu_locate_upgrade_slots();
  fl_disconnect();

  t_start(1);
  state = dfu_getstate();
  t_end();
  assert(state == APP_IDLE);

  t_start(2);
  dfu_detach();
  t_end();
  t_start(3);
  state = dfu_getstate();
  t_end();
  assert(state == APP_DETACH);

  ret = fl_connectToOneDevice(ports, spec);
  assert(ret == 0);

  t_start(4);
  dfu_bus_reset();
  t_end();
  t_start(5);
  state = dfu_getstate();
  t_end();
  assert(state == DFU_IDLE);
}

FILE * movable write(FILE * movable bin_file, int block_size, int marker)
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

    t_start(6);
    dfu_dnload(marker | block_count, read, block);
    t_end();

    do {
      t_start(7);
      ret = dfu_getstatus();
      t_end();
      assert(ret.status == DFU_OK);
      delay_milliseconds(ret.poll_timeout_msec);
    } while (ret.state == DFU_DNBUSY);

    assert(ret.state == DFU_DNLOAD_IDLE);

    block_count++;
  }

  t_start(8);
  dfu_dnload(0, 0, block);
  t_end();
  state = dfu_getstate();
  t_end();
  assert(state == DFU_MANIFEST_SYNC);

  do {
    t_start(9);
    ret = dfu_getstatus();
    t_end();
    assert(ret.status == DFU_OK);
    delay_microseconds(ret.poll_timeout_msec);
  } while (ret.state == DFU_DNBUSY);

  return move(bin_file);
}

int main(unsigned argc, char * unsafe argv[argc])
{
  const int block_size = 128;

  assert(argc == 4);

  FILE * movable boot_file = fopen((char*)argv[1], "rb");
  FILE * movable data_file = fopen((char*)argv[2], "rb");
  unsafe {
    sscanf(argv[3], "%d", &timing.threshold);
  }

  write_begin();

  boot_file = write(move(boot_file), block_size, 0);
  data_file = write(move(data_file), block_size, DFU_BLOCK_NUM_DATA_IMAGE_MARKER);

  fclose(move(boot_file));
  fclose(move(data_file));

  fl_disconnect();

  printstr("PASS\n");
  return 0;
}
