// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_SUB_SM_H
#define DFU_SUB_SM_H

#include <stdint.h>

#include "dfu_types.h"
#include "fifo.h"

struct dfu_sub_request {
  enum dfu_cmd_request request;
  int32_t time_allowed_msec;
};

struct dfu_sub_response {
  enum dfu_status status;
  int32_t flash_finalised;
};

enum dnload_sub_state {
  DNLOAD_SYNC,
  DNLOAD_ERASING,
  DNLOAD_WRITING
};

void sub_sm_clear(void);
int32_t sub_sm_get_poll_timeout(void);

struct dfu_sub_response sub_sm_process_dnload(struct fifo &dfu_fifo);
struct dfu_sub_response sub_sm_process_manifest(struct fifo &dfu_fifo);

void sub_sm_print_profiler(void);

#endif /* DFU_SUB_SM_H */
