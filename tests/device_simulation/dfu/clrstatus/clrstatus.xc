// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <print.h>

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

#include "dfu.h"

int main(void)
{
  enum dfu_state state;

  state = dfu_getstate();
  assert(state == APP_IDLE);

  dfu_detach();
  state = dfu_getstate();
  assert(state == APP_DETACH);

  dfu_bus_reset();
  state = dfu_getstate();
  assert(state == DFU_IDLE);

  // another detach is unexpected here
  dfu_detach();
  state = dfu_getstate();
  assert(state == DFU_ERROR);

  // clear error state
  dfu_clrstatus();
  state = dfu_getstate();
  assert(state == DFU_IDLE);

  printstr("PASS\n");
  return 0;
}
