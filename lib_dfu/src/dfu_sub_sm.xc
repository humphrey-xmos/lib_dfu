// Copyright 2011-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include "dfu_sub_sm.h"

#include <xs1.h>
#include <platform.h>
#include <string.h>

#define DEBUG_UNIT DFU_PROFILER
#define DEBUG_PRINT_ENABLE_DFU_PROFILER 0
#include "debug_print.h"
#include "xassert.h"

#include "dfu.h"
#include "dfu_flash.h"
#include "fifo.h"

static enum dnload_sub_state sub_state = DNLOAD_SYNC;
static uint32_t poll_timeout = 0;

static timer t_profiler;
static unsigned t_profiler_start = 0;
static unsigned t_profiler_end = 0;

static unsigned t_profile_connect = 0;
static unsigned t_profile_first_erase = 0;
static unsigned t_profile_first_write = 0;
// static unsigned t_profile_second_write = 0;

#if DEBUG_PRINT_ENABLE_DFU_PROFILER
static const char * unsafe dnload_sub_state_str(enum dnload_sub_state s)
{
  unsafe {
    switch (s) {
      case DNLOAD_SYNC:                     return "SYNC";
      case DNLOAD_ERASING:                  return "ERASING";
      case DNLOAD_WRITING:                  return "WRITING";
      default:                              return "?";
    }
  }
}
#endif

static void sub_transition_dnload(enum dnload_sub_state new)
{
  unsafe {
    debug_printf("DFU DNLOAD: %s -> %s\n", dnload_sub_state_str(sub_state), dnload_sub_state_str(new));
  }
  sub_state = new;
}

void sub_sm_clear(void)
{
  poll_timeout = POLL_TIMEOUT_DNLOAD_ENTRY_MSEC;
  sub_state = DNLOAD_SYNC;

  t_profile_connect = 0;
  t_profile_first_erase = 0;
  t_profile_first_write = 0;
}

int32_t sub_sm_get_poll_timeout(void)
{
  return poll_timeout;
}

static enum dfu_status sub_sm_erase_sectors(int32_t duration_ms)
{
  if (duration_ms <= 0) {
    return DFU_errUNKNOWN;
  }
  enum dfu_status status = DFU_errNOTDONE;
  timer tmr;
  unsigned time;
  tmr :> time;
  unsigned end_time = time + (XS1_TIMER_KHZ * (unsigned)duration_ms);

  while(timeafter(end_time, time)) // Erase as many sectors as we can in given time duration
  {
    enum flash_status erase_status = flash_erase_sector_async(FLASH_MAX_UPGRADE_SIZE);
    if (erase_status == DFU_FLASH_OK) {
      status = DFU_OK;
      break;
    } else if (erase_status == DFU_FLASH_BUSY) {
      /* wait */
    } else {
      status = DFU_errERASE;
      break;
    }
    tmr :> time;
  }
  return status;
}

static enum dfu_status sub_sm_flash_write_page(struct fifo &dfu_fifo, uint8_t *page, int32_t page_size_bytes)
{  
  enum dfu_status status = DFU_errTARGET;

  int32_t flash_page_bytes = flash_get_page_size();
  if (page_size_bytes != flash_page_bytes) {
    // sanity check - this should never happen
    return DFU_errPROG;
  }
  // drain conversion buffer of partial page, if any
  int32_t remaining_bytes = fifo_size(dfu_fifo);
  if (remaining_bytes > page_size_bytes) {
    remaining_bytes = page_size_bytes;
  }

  if (remaining_bytes != 0) {
    // TODO add fifo function to access pointer to memory to avoid this copy, if performance of this is an issue.
    if (fifo_block_dequeue(dfu_fifo, page, remaining_bytes) == FIFO_OK) {
      memset(&page[remaining_bytes], 0xFF, (page_size_bytes - remaining_bytes));
      t_profiler :> t_profiler_start;
      if (flash_write_page(page, page_size_bytes) != DFU_FLASH_OK) {
        status = DFU_errWRITE;
      } else {
        status = DFU_OK;
      }
      t_profiler :> t_profiler_end;
    } else {
      status = DFU_errNOTDONE;
    }
  }
  return status;
}

struct dfu_sub_response sub_sm_process_dnload(struct fifo &dfu_fifo)
{
  uint8_t page[DFU_FLASH_PAGE_SIZE_BYTES];
  struct dfu_sub_response response = { DFU_errUNKNOWN, 0 };
  
  switch (sub_state) {
    case DNLOAD_SYNC:
      poll_timeout = POLL_TIMEOUT_DNLOAD_ENTRY_MSEC;
      if (!flash_is_connected()) {
        t_profiler :> t_profiler_start;
        if (flash_init() != DFU_FLASH_OK) {
          response.status = DFU_errWRITE;
          return response;
        }
        t_profiler :> t_profiler_end;
        t_profile_connect = t_profiler_end - t_profiler_start;
      }

      t_profiler :> t_profiler_start;
      // TODO - replace FLASH_MAX_UPGRADE_SIZE with image size from first page downloaded
      enum flash_status erase_status = flash_erase_sector_async(FLASH_MAX_UPGRADE_SIZE);
      if ((erase_status != DFU_FLASH_OK) && (erase_status != DFU_FLASH_BUSY)) {
        response.status = DFU_errERASE;
        return response;
      }
      t_profiler :> t_profiler_end;
      t_profile_first_erase = t_profiler_end - t_profiler_start;

      poll_timeout = POLL_TIMEOUT_DNLOAD_ERASE_MSEC;
      sub_transition_dnload(DNLOAD_ERASING);
      response.status = DFU_OK;

      break;

    // TODO - support time bound repeated erase cycle.
    case DNLOAD_ERASING:
      poll_timeout = POLL_TIMEOUT_DNLOAD_ERASE_MSEC;
      enum dfu_status status = sub_sm_erase_sectors((DFU_FLASH_ERASE_CYCLE_MSEC - 5));

      if (status == DFU_OK) {
        // sector erase completed, move on to page write
        sub_transition_dnload(DNLOAD_WRITING);
        poll_timeout = POLL_TIMEOUT_DNLOAD_FIRST_WRITE_MSEC;

        response.status = sub_sm_flash_write_page(dfu_fifo, page, sizeof(page));
        t_profile_first_write = t_profiler_end - t_profiler_start;

      } else if (status == DFU_errNOTDONE) {
        // still erasing, remain in this state and wait for next poll
        response.status = DFU_OK;

      } else {
        response.status = DFU_errERASE;
      }
      break;

    case DNLOAD_WRITING:
      poll_timeout = POLL_TIMEOUT_DNLOAD_WRITE_MSEC;
      response.status = sub_sm_flash_write_page(dfu_fifo, page, sizeof(page));
      break;

    default:
      sub_state = DNLOAD_SYNC;
      response.status = DFU_errUNKNOWN;
      break;
  }

  return response;
}

struct dfu_sub_response sub_sm_process_manifest(struct fifo &dfu_fifo)
{
  struct dfu_sub_response sub_sm = { DFU_errUNKNOWN, 0 };
  uint8_t page[DFU_FLASH_PAGE_SIZE_BYTES];

  if (sub_state != DNLOAD_WRITING) {
    sub_sm = sub_sm_process_dnload(dfu_fifo);

  } else {
    sub_state = DNLOAD_SYNC;
    poll_timeout = POLL_TIMEOUT_DNLOAD_MANIFEST_MSEC;

    sub_sm.status = sub_sm_flash_write_page(dfu_fifo, page, sizeof(page));

    if (fifo_is_empty(dfu_fifo)) {
      enum flash_status status = flash_finalise_write();
      if (status != DFU_FLASH_OK) {
        debug_printf("DFU: flash_finalise_write status: %d\n", status);
        sub_sm.status = DFU_errPROG;
      } else {
        sub_sm.status = DFU_OK;
        sub_sm.flash_finalised = 1;
      }
      sub_sm_print_profiler();
    }
  }
  return sub_sm;
}

void sub_sm_print_profiler(void)
{
  debug_printf("DFU: profile results:\n");
  debug_printf("  Connect time: %u ms (target %d ms)\n", t_profile_connect, POLL_TIMEOUT_DNLOAD_ENTRY_MSEC);
  debug_printf("  First erase time: %u ms (target %d ms)\n", t_profile_first_erase, POLL_TIMEOUT_DNLOAD_ERASE_MSEC);
  debug_printf("  First write time: %u ms (target %d ms)\n", t_profile_first_write, POLL_TIMEOUT_DNLOAD_FIRST_WRITE_MSEC);
}
