// Copyright (c) 2019-2020, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <print.h>

#define _Bool int
#include <stdbool.h>

#define DEBUG_UNIT DFU
#define DEBUG_PRINT_ENABLE_DFU 0
#include "debug_print.h"

#include "dfu_buffer_converter.h"
#include "dfu_flash.h"
#include "dfu_flash_result.h"
#include "dfu.h"

#define POLL_TIMEOUT_MSEC 1

static enum dfu_state state = APP_IDLE;
static enum dfu_status status = DFU_OK;
static int error_info = 0;

static struct buffer_converter converter;

static struct {
  unsigned boot, data;
} upgrade_slots = {0, 0};

static struct {
  int next_page_address;
  char page[DFU_PAGE_SIZE_MAX_BYTES];
  bool page_ready;
  enum dnload_sub_state {
    DNLOAD_SYNC,
    DNLOAD_ERASING_SECTOR,
    DNLOAD_WRITING_PAGE
  } sub_state;
} dnload = {0, {}, false, DNLOAD_SYNC};

enum dfu_request {
  DFU_DETACH,
  DFU_DNLOAD,
  DFU_UPLOAD,
  DFU_GETSTATUS,
  DFU_CLRSTATUS,
  DFU_GETSTATE,
  DFU_ABORT
};

#if DEBUG_PRINT_ENABLE_DFU
static const char * unsafe request_str(enum dfu_request r)
{
  unsafe {
    switch (r) {
      case DFU_DETACH:                return "DETACH";
      case DFU_DNLOAD:                return "DNLOAD";
      case DFU_UPLOAD:                return "UPLOAD";
      case DFU_GETSTATUS:             return "GETSTATUS";
      case DFU_CLRSTATUS:             return "CLRSTATUS";
      case DFU_GETSTATE:              return "GETSTATE";
      case DFU_ABORT:                 return "ABORT";
      default:                        return "?";
    }
  }
}

static const char * unsafe state_str(enum dfu_state s)
{
  unsafe {
    switch (s) {
      case APP_IDLE:                  return "appIDLE";
      case APP_DETACH:                return "appDETACH";
      case DFU_IDLE:                  return "dfuIDLE";
      case DFU_DNLOAD_SYNC:           return "dfuDNLOAD-SYNC";
      case DFU_DNBUSY:                return "dfuDNBUSY";
      case DFU_DNLOAD_IDLE:           return "dfuDNLOAD-IDLE";
      case DFU_MANIFEST_SYNC:         return "dfuMANIFEST-SYNC";
      case DFU_MANIFEST:              return "dfuMANIFEST";
      case DFU_MANIFEST_WAIT_RESET:   return "dfuMANIFEST-WAIT-RESET";
      case DFU_UPLOAD_IDLE:           return "dfuUPLOAD-IDLE";
      case DFU_ERROR:                 return "dfuERROR";
      default:                        return "?";
    }
  }
}

static const char * unsafe dnload_sub_state_str(enum dnload_sub_state s)
{
  unsafe {
    switch (s) {
      case DNLOAD_SYNC:               return "SYNC";
      case DNLOAD_ERASING_SECTOR:     return "ERASING_SECTOR";
      case DNLOAD_WRITING_PAGE:       return "WRITING_PAGE";
      default:                        return "?";
    }
  }
}

static const char * unsafe status_str(enum dfu_status s)
{
  unsafe {
    switch (s) {
      case DFU_OK:                    return "OK";
      case ERR_TARGET:                return "errTARGET";
      case ERR_FILE:                  return "errFILE";
      case ERR_WRITE:                 return "errWRITE";
      case ERR_ERASE:                 return "errERASE";
      case ERR_CHECK_ERASED:          return "errCHECK_ERASED";
      case ERR_PROG:                  return "errPROG";
      case ERR_VERIFY:                return "errVERIFY";
      case ERR_ADDRESS:               return "errADDRESS";
      case ERR_NOTDONE:               return "errNOTDONE";
      case ERR_FIRMWARE:              return "errFIRMWARE";
      case ERR_VENDOR:                return "errVENDOR";
      case ERR_USBR:                  return "errUSBR";
      case ERR_POR:                   return "errPOR";
      case ERR_UNKNOWN:               return "errUNKNOWN";
      case ERR_STALLED_PKT:           return "errSTALLEDPKT";
      default:                        return "?";
    }
  }
}
#endif

static void normal_transition(enum dfu_state new)
{
  unsafe {
    debug_printf("DFU: %s -> %s\n", state_str(state), state_str(new));
  }
  status = DFU_OK;
  state = new;
}

static void error_condition(enum dfu_status code, int extra)
{
  if (dnload.page_ready)
    dnload.page_ready = false;

  unsafe {
    debug_printf("DFU: %s -> DFU_ERROR (%s %d)\n",
                 state_str(state), status_str(code), extra);
  }
  status = code;
  state = DFU_ERROR;
  error_info = extra;
}

static void sub_transition_dnload(enum dnload_sub_state new)
{
  unsafe {
    debug_printf("DFU DNLOAD: %s -> %s\n",
                 dnload_sub_state_str(dnload.sub_state),
                 dnload_sub_state_str(new));
  }
  dnload.sub_state = new;
}

static bool is_address_in_an_upgrade_slot(int address)
{
  if (address >= upgrade_slots.boot && address < flash_get_data_partition_base())
    return true;

  if (address >= upgrade_slots.data && address < flash_get_size())
    return true;

  return false;
}


static enum dfu_status getstatus_from_dnload(bool &busy)
{
  busy = true;

  switch (dnload.sub_state) {
    case DNLOAD_SYNC:
      if (dnload.page_ready) {
        if (flash_is_first_whole_page_in_sector(dnload.next_page_address)) {
          if (!is_address_in_an_upgrade_slot(dnload.next_page_address))
            return ERR_ADDRESS;

          sub_transition_dnload(DNLOAD_ERASING_SECTOR);

          if (flash_erase_sector_async(dnload.next_page_address) != 0)
            return ERR_ERASE;
        }
        else {
          if (!is_address_in_an_upgrade_slot(dnload.next_page_address))
            return ERR_ADDRESS;

          sub_transition_dnload(DNLOAD_WRITING_PAGE);

          if (flash_write_page_async(dnload.next_page_address, dnload.page) != 0)
            return ERR_WRITE;
        }
      }
      else {
        busy = false;
      }
      break;

    case DNLOAD_ERASING_SECTOR:
      if (!flash_is_busy()) {
        if (!flash_is_sector_erased(dnload.next_page_address))
          return ERR_CHECK_ERASED;

        if (!is_address_in_an_upgrade_slot(dnload.next_page_address))
          return ERR_ADDRESS;

        sub_transition_dnload(DNLOAD_WRITING_PAGE);

        if (flash_write_page_async(dnload.next_page_address, dnload.page) != 0)
          return ERR_WRITE;
      }
      break;

    case DNLOAD_WRITING_PAGE:
      if (!flash_is_busy()) {
        if (!flash_verify_page(dnload.next_page_address, dnload.page))
          return ERR_VERIFY;

        const int page_size_bytes = flash_get_page_size();

        sub_transition_dnload(DNLOAD_SYNC);

        dnload.next_page_address += page_size_bytes;

        if (buffer_converter_pull(converter, dnload.page, page_size_bytes) != 0) {
          dnload.page_ready = false;
          busy = false;
        }
      }
      break;
  }

  return DFU_OK;
}

static int dnload_block(const char write_block[], int block_num,
                        int block_size_bytes)
{
  const int page_size_bytes = flash_get_page_size();

  // it should be an error for the sub-state machine to go out of sync
  // eg host omitting a GETSTATUS request
  if (dnload.sub_state != DNLOAD_SYNC)
    return 1;

  // there should never be an unprocessed page when DNLOAD request is sent
  // an unprocessed page is written out first with repeated GETSTATUS requests
  if (dnload.page_ready)
    return 2;

  if (block_size_bytes > 0) {
    // peek at main state here to determine if this is the first DNLOAD block of
    // a given operation so we can suitably start things off
    if (state == DFU_IDLE) {
      dnload.next_page_address = block_num & DFU_BLOCK_NUM_DATA_IMAGE_MARKER
                                 ? upgrade_slots.data : upgrade_slots.boot;
      buffer_converter_reset(converter);
    }

    // non-zero return value from the push function indicates not enough space
    // in the queue of blocks awaiting conversion to pages
    // for some reason there are have been not enough pulls or too many pushes
    if (buffer_converter_push(converter, write_block, block_size_bytes) != 0)
      return 3;

    // normal scenario: once we have enough blocks to make one page, commit this
    // page for the next stage: optional sector erase followed by one or more
    // page writes
    if (buffer_converter_pull(converter, dnload.page, page_size_bytes) == 0)
      dnload.page_ready = true;
  }

  if (block_size_bytes == 0) {
    // drain conversion buffer of partial page, if any
    if (buffer_converter_padded_pull(converter, dnload.page, page_size_bytes) > 0)
      dnload.page_ready = true;
  }

  return 0;
}

static void request_with_arguments(enum dfu_request request,
                                   const char (&?write_block)[DFU_BLOCK_SIZE_MAX_BYTES],
                                   char (&?read_block)[DFU_BLOCK_SIZE_MAX_BYTES],
                                   int block_size_bytes, int write_block_num)
{
#if DEBUG_PRINT_ENABLE_DFU
  debug_printf("DFU: %s", request_str(request));
  if (request == DFU_DNLOAD)
    debug_printf(" 0x%X %d\n", write_block_num, block_size_bytes);
  else
    debug_printf("\n");
#endif
  enum dfu_status status;
  int ret;

  switch (state) {
    case APP_IDLE:
      if (request == DFU_DETACH) {
        normal_transition(APP_DETACH);
      }
      // no other requests expected, stay in appIDLE
      break;

    case APP_DETACH:
      if (request != DFU_GETSTATUS && request != DFU_GETSTATE) {
        // no other requests expected, return to appIDLE
        normal_transition(APP_IDLE);
      }
      break;

    case DFU_IDLE:
      if (request == DFU_DNLOAD) {
        ret = dnload_block(write_block, write_block_num, block_size_bytes);
        if (ret != 0)
          error_condition(ERR_UNKNOWN, ret);
        else
          normal_transition(DFU_DNLOAD_SYNC);
      }
      else if (request != DFU_GETSTATUS && request != DFU_GETSTATE) {
        // no other requests expected, defined as error
        error_condition(ERR_STALLED_PKT, request);
      }
      break;

    case DFU_DNLOAD_SYNC:
      if (request == DFU_GETSTATUS) {
        bool busy = false;
        status = getstatus_from_dnload(busy);
        if (status != DFU_OK) {
          error_condition(status, 0);
        }
        else {
          if (busy) {
            normal_transition(DFU_DNBUSY);
            normal_transition(DFU_DNLOAD_SYNC);
          }
          else {
            normal_transition(DFU_DNLOAD_IDLE);
          }
        }
      }
      break;

    case DFU_MANIFEST_SYNC:
      if (request == DFU_GETSTATUS) {
        bool busy = false;
        status = getstatus_from_dnload(busy);
        if (status != DFU_OK) {
          error_condition(status, 0);
        }
        else {
          if (busy) {
            normal_transition(DFU_MANIFEST);
            normal_transition(DFU_MANIFEST_SYNC);
          }
          else {
            normal_transition(DFU_IDLE);
            // flash could be disconnected now
            ret = flash_set_write_disable();
            if (ret != 0)
              error_condition(ERR_WRITE, ret);
          }
        }
      }
      else if (request != DFU_GETSTATE) {
        error_condition(ERR_STALLED_PKT, request);
      }
      break;

    case DFU_DNLOAD_IDLE:
      if (request == DFU_DNLOAD) {
        if (block_size_bytes == 0) {
          ret = dnload_block(write_block, 0, 0);
          if (ret != 0)
            error_condition(ERR_UNKNOWN, ret);
          else
            normal_transition(DFU_MANIFEST_SYNC);
        }
        else {
          ret = dnload_block(write_block, write_block_num, block_size_bytes);
          if (ret != 0)
            error_condition(ERR_UNKNOWN, ret);
          else
            normal_transition(DFU_DNLOAD_SYNC);
        }
      }
      else if (request != DFU_GETSTATE) {
        error_condition(ERR_UNKNOWN, request);
      }
      break;

    case DFU_ERROR:
      if (request == DFU_CLRSTATUS) {
        normal_transition(DFU_IDLE);
      }
      break;
  }
}

static void request(enum dfu_request request)
{
  request_with_arguments(request, null, null, 0, 0);
}

enum dfu_state dfu_getstate(void)
{
  request(DFU_GETSTATE);
  return state;
}

struct dfu_getstatus dfu_getstatus(void)
{
  request(DFU_GETSTATUS);

  struct dfu_getstatus ret;
  ret.status = status;
  ret.state = state;
  ret.poll_timeout_msec = POLL_TIMEOUT_MSEC;

  // special treament for the sync states:
  // make it look like we've stayed in the busy state (either dfuDNBUSY or
  // dfuMANIFEST) for the duration of poll timeout, while we actually leave
  // immediately (going back to the sync state)
  if (state == DFU_DNLOAD_SYNC)
    ret.state = DFU_DNBUSY;
  else if (state == DFU_MANIFEST_SYNC)
    ret.state = DFU_MANIFEST;
  else
    ret.poll_timeout_msec = 0;

  return ret;
}

void dfu_clrstatus(void)
{
  request(DFU_CLRSTATUS);
}

void dfu_detach(void)
{
  request(DFU_DETACH);
}

void dfu_bus_reset(void)
{
  if (state == APP_DETACH)
    normal_transition(DFU_IDLE);
  else if (state == APP_IDLE)
    normal_transition(APP_IDLE);
  else
    error_condition(ERR_USBR, state);
}

void dfu_timeout_detach(void)
{
  if (state == APP_DETACH) {
    normal_transition(APP_IDLE);
  }
  else {
    debug_printf("unexpected detach timeout call\n");
    // remain in current state, no error code indication
  }
}

void dfu_dnload(unsigned short block_num, size_t block_size_bytes,
                const char block[DFU_BLOCK_SIZE_MAX_BYTES])
{
  request_with_arguments(DFU_DNLOAD, block, null, block_size_bytes, block_num);
}

int dfu_get_error_info(void)
{
  return error_info;
}

int dfu_locate_upgrade_slots(void)
{
  if (flash_locate_boot_upgrade_slot(upgrade_slots.boot) != 0)
    return 1;

  if (flash_locate_data_upgrade_slot(upgrade_slots.data) != 0)
    return 2;

  return 0;
}

bool dfu_is_flash_suitable(const fl_QuadDeviceSpec spec[1])
{
  if (spec[0].pageSize > DFU_PAGE_SIZE_MAX_BYTES)
    return false;

  if (spec[0].sectorLayout != SECTOR_LAYOUT_REGULAR)
    return false;

  if (spec[0].sectorEraseSize != spec[0].sectorSizes.regularSectorSize)
    return false;

  return true;
}
