// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <print.h>

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

#include "dfu.h"

int main(void)
{
  struct dfu_getstatus ret;
  enum dfu_state state;

  state = dfu_getstate();
  assert(state == APP_IDLE);

  dfu_detach();
  ret = dfu_getstatus();
  assert(ret.state == APP_DETACH);
  assert(ret.status == DFU_OK);

  dfu_bus_reset();
  ret = dfu_getstatus();
  assert(ret.state == DFU_IDLE);
  assert(ret.status == DFU_OK);

  printstr("PASS\n");
  return 0;
}
