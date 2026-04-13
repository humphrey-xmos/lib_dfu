// Copyright 2019-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <print.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>

#define DEBUG_UNIT DFU
#define DEBUG_PRINT_ENABLE_DFU 0
#include "debug_print.h"
#include "xassert.h"

#include "dfu_flash.h"
#include "dfu.h"
#include "dfu_reboot.h"
#include "dfu_sub_sm.h"
#include "fifo.h"

static enum dfu_state state = STATE_APP_IDLE;
static enum dfu_status status = DFU_OK;
static int32_t error_info = 0;

static struct fifo dfu_fifo;
static uint8_t dfu_fifo_storage[DFU_FLASH_PAGE_SIZE_BYTES];

#if DEBUG_PRINT_ENABLE_DFU
static const char * unsafe request_str(enum dfu_cmd_request r)
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

      case XMOS_DFU_BUS_RESET:        return "XMOS_DFU_BUS_RESET";
      case XMOS_DFU_GET_DESCRIPTOR:   return "XMOS_DFU_GET_DESCRIPTOR";

      case DFU_DEFERRED_ACTION_FLASH_WRITE: return "DEFERRED_ACTION_FLASH_WRITE";
      case DFU_DEFERRED_ACTION_FLASH_MANIFEST: return "DEFERRED_ACTION_FLASH_MANIFEST";
      
      case XMOS_DFU_REVERTFACTORY:    return "XMOS_DFU_REVERTFACTORY";
      default:                        return "?";
    }
  }
}

static const char * unsafe state_str(enum dfu_state s)
{
  unsafe {
    switch (s) {
      case STATE_APP_IDLE:                  return "appIDLE";
      case STATE_APP_DETACH:                return "appDETACH";
      case STATE_DFU_IDLE:                  return "dfuIDLE";
      case STATE_DFU_DOWNLOAD_SYNC:         return "dfuDNLOAD-SYNC";
      case STATE_DFU_DOWNLOAD_BUSY:         return "dfuDNBUSY";
      case STATE_DFU_DOWNLOAD_IDLE:         return "dfuDNLOAD-IDLE";
      case STATE_DFU_MANIFEST_SYNC:         return "dfuMANIFEST-SYNC";
      case STATE_DFU_MANIFEST:              return "dfuMANIFEST";
      case STATE_DFU_MANIFEST_WAIT_RESET:   return "dfuMANIFEST-WAIT-RESET";
      case STATE_DFU_UPLOAD_IDLE:           return "dfuUPLOAD-IDLE";
      case STATE_DFU_ERROR:                 return "dfuERROR";
      default:                              return "?";
    }
  }
}

static const char * unsafe status_str(enum dfu_status s)
{
  unsafe {
    switch (s) {
      case DFU_OK:                      return "OK";
      case DFU_errTARGET:               return "errTARGET";
      case DFU_errFILE:                 return "errFILE";
      case DFU_errWRITE:                return "errWRITE";
      case DFU_errERASE:                return "errERASE";
      case DFU_errCHECK_ERASED:         return "errCHECK_ERASED";
      case DFU_errPROG:                 return "errPROG";
      case DFU_errVERIFY:               return "errVERIFY";
      case DFU_errADDRESS:              return "errADDRESS";
      case DFU_errNOTDONE:              return "errNOTDONE";
      case DFU_errFIRMWARE:             return "errFIRMWARE";
      case DFU_errVENDOR:               return "errVENDOR";
      case DFU_errUSBR:                 return "errUSBR";
      case DFU_errPOR:                  return "errPOR";
      case DFU_errUNKNOWN:              return "errUNKNOWN";
      case DFU_errSTALLED_PKT:          return "errSTALLEDPKT";
      default:                          return "?";
    }
  }
}
#endif

static struct dfu_cmd_response normal_transition(enum dfu_state new)
{
  unsafe {
    debug_printf("DFU: %s -> %s\n", state_str(state), state_str(new));
  }
  status = DFU_OK;
  state = new;
  struct dfu_cmd_response response = { DFU_API_SUCCESS, 0, 0 };
  return response;
}

static struct dfu_cmd_response error_condition(enum dfu_status code, int32_t extra)
{
  unsafe {
    debug_printf("DFU: %s -> DFU_ERROR (%s %d)\n",
                 state_str(state), status_str(code), extra);
  }
  status = code;
  state = STATE_DFU_ERROR;
  error_info = extra;
  struct dfu_cmd_response response = { DFU_API_ERROR, 0, 0 };
  return response;
}

static int32_t dfufifo_is_page_ready(void)
{
  return (fifo_size(dfu_fifo) >= DFU_FLASH_PAGE_SIZE_BYTES);
}

static struct dfu_cmd_response build_status(uint8_t block[], uint32_t timeout, struct dfu_cmd_response response) {
  memset(block, 0, DFU_GET_STATUS_PAYLOAD_SIZE_BYTES);
  block[DFU_GETSTATUS_STATUS_INDEX] = status;
  memcpy(&block[DFU_GETSTATUS_POLL_TIMEOUT_INDEX], &timeout, DFU_GETSTATUS_POLL_TIMEOUT_BYTES);

  // special treatment for the sync states: make it look like we've stayed in the busy state (either dfuDNBUSY or
  // dfuMANIFEST) for the duration of poll timeout, while we actually leave immediately (going back to the sync state)
  if (state == STATE_DFU_DOWNLOAD_SYNC) {
    block[DFU_GETSTATUS_STATE_INDEX] = STATE_DFU_DOWNLOAD_BUSY;
  } else if (state == STATE_DFU_MANIFEST_SYNC) {
    block[DFU_GETSTATUS_STATE_INDEX] = STATE_DFU_MANIFEST;
  } else {
    block[DFU_GETSTATUS_STATE_INDEX] = state;
  }
  
  response.status = DFU_API_SUCCESS;
  response.return_data_len = DFU_GET_STATUS_PAYLOAD_SIZE_BYTES;
  /* Do not update deferred_action as this is passed through */
  return response;
}

static enum dfu_api_status upload_block(uint8_t read_block[], int32_t block_size_bytes)
{
  if (fifo_is_empty(dfu_fifo)) {
    if (flash_read_page(dfu_fifo_storage, DFU_FLASH_PAGE_SIZE_BYTES) != DFU_FLASH_OK) {
      return DFU_API_ERROR;
    } else {
      // TODO - fix snooping into fifo
      fifo_init(dfu_fifo, dfu_fifo_storage, sizeof(dfu_fifo_storage));
      dfu_fifo.count = DFU_FLASH_PAGE_SIZE_BYTES;
    }
  }

  if (fifo_block_dequeue(dfu_fifo, read_block, block_size_bytes) == FIFO_OK) {
    return DFU_API_SUCCESS;
  }

  return DFU_API_ERROR;
}

static struct dfu_cmd_response state_app_idle(enum dfu_cmd_request request) {
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };
  if (request == XMOS_DFU_BUS_RESET) {
    response.status = DFU_API_SUCCESS;

  } else if (request == DFU_DETACH) {
    response = normal_transition(STATE_APP_DETACH);
    response.deferred_request = DFU_DEFERRED_ACTION_REBOOT_TO_DFU;

  } else if (request == DFU_ABORT) {
    response.status = DFU_API_SUCCESS;

  }
  // no other requests expected, stay in appIDLE
  return response;
}

static struct dfu_cmd_response state_detach(enum dfu_cmd_request request) {
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };
  if (request == XMOS_DFU_BUS_RESET) {
    response = normal_transition(STATE_DFU_IDLE);
    // TODO - USB DFU entry should send detach request from app init. After reboot triggered from DETACH.
#if defined(DFU_CONFIG_USB_INBAND_FUNCTIONS) && (DFU_CONFIG_USB_INBAND_FUNCTIONS == 1)
    if (!flash_is_connected()) {
      if (flash_init() != DFU_FLASH_OK) {
        response = error_condition(DFU_errTARGET, 0);
        return response;
      }
    }
#else
    response.deferred_request = DFU_DEFERRED_ACTION_FLASH_CONNECT;
#endif

  } else if ((request != DFU_GETSTATUS) && (request != DFU_GETSTATE)) {
    // no other requests expected, return to appIDLE, but respond with STALL.
    response = normal_transition(STATE_APP_IDLE);
    response.status = DFU_API_ERROR;
  }
  return response;
}

static struct dfu_cmd_response action_entry_dnload(const uint8_t (&?write_block)[DFU_TRANSFER_SIZE_BYTES],
                                                  int32_t block_size_bytes, int32_t &?block_num) {
  // TOTO - use this
  UNUSED(block_num);

  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };
  if (block_size_bytes <= 0) {
    response = error_condition(DFU_errADDRESS, 0);
    return response;
  }
  fifo_init(dfu_fifo, dfu_fifo_storage, sizeof(dfu_fifo_storage));
  if (fifo_block_enqueue(dfu_fifo, write_block, block_size_bytes) != FIFO_OK) {
    response = error_condition(DFU_errUNKNOWN, 0);
  } else {
    response = normal_transition(STATE_DFU_DOWNLOAD_SYNC);
  }
  // TODO - test first page for valid image and return errFILE if not valid
  return response;
}

static struct dfu_cmd_response action_entry_upload(uint8_t (&?read_block)[DFU_TRANSFER_SIZE_BYTES],
                                                  int32_t block_size_bytes, int32_t &?read_length) {
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };

#if defined(DFU_CONFIG_USB_INBAND_FUNCTIONS) && (DFU_CONFIG_USB_INBAND_FUNCTIONS == 1)
  if (!flash_is_connected()) {
    if (flash_init() != DFU_FLASH_OK) {
      response = error_condition(DFU_errTARGET, 0);
      return response;
    }
  }
#endif
  fifo_init(dfu_fifo, dfu_fifo_storage, sizeof(dfu_fifo_storage));
  
  // TODO - profile this.
  struct flash_data_status start_status = flash_start_read();
  if (start_status.status == DFU_FLASH_READ_NO_IMAGE) {
    read_length = 0;
    response = normal_transition(STATE_DFU_UPLOAD_IDLE);
    response.return_data_len = 0;

  } else if (start_status.status != DFU_FLASH_OK) {
    response = error_condition(DFU_errFILE, 0);

  } else {
    read_length = start_status.data;
    // TODO - for no-clock-stretching we may have to read out-of-band
    enum dfu_api_status upload = upload_block(read_block, block_size_bytes);
    if (upload != DFU_API_SUCCESS) {
      response = error_condition(DFU_errFILE, upload);
    } else {
      response = normal_transition(STATE_DFU_UPLOAD_IDLE);
      response.return_data_len = (read_length < block_size_bytes) ? read_length : block_size_bytes;
      read_length -= block_size_bytes;
    }
  }
  return response;
}

static struct dfu_cmd_response action_revert_factory(void) {
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };

  int32_t sector_size = flash_get_sector_size();
  enum flash_status erase_status = flash_erase_sector_async(sector_size);
  if (erase_status != DFU_FLASH_BUSY) {
    debug_printf("Factory revert: failed to start sector erase\n");
  } else {
    while (flash_erase_sector_async(sector_size) == DFU_FLASH_BUSY) {
      // Wait
    }
  }
  // We always succeed for now, is there a case to report error if there is no upgrade image to delete?
  response.status = DFU_API_SUCCESS;
  return response;
}

static struct dfu_cmd_response state_dfu_idle(enum dfu_cmd_request request) {
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };

  if (request == DFU_DEFERRED_ACTION_FLASH_CONNECT) {
    if (flash_init() != DFU_FLASH_OK) {
      response = error_condition(DFU_errTARGET, 0);
    } else {
      response.status = DFU_API_SUCCESS;
    }

  } else if (request == XMOS_DFU_REVERTFACTORY) {
#if defined(DFU_CONFIG_USB_INBAND_FUNCTIONS) && (DFU_CONFIG_USB_INBAND_FUNCTIONS == 0)
    response.deferred_request = DFU_DEFERRED_ACTION_REVERT_FACTORY;
    response.status = DFU_API_SUCCESS;
    
  } else if (request == DFU_DEFERRED_ACTION_REVERT_FACTORY) {
#endif
    response = action_revert_factory();

  } else if (request == DFU_DETACH) {
    /* Handle detach as exit from DFUidle for Windows */
    flash_deinit();
    response = normal_transition(STATE_APP_IDLE);
    response.deferred_request = DFU_DEFERRED_ACTION_REBOOT;

  } else if (request == DFU_ABORT) {
    response.status = DFU_API_SUCCESS;

  } else if ((request != DFU_GETSTATUS) && (request != DFU_GETSTATE) && (request != XMOS_DFU_BUS_RESET)) {
    // no other requests expected, defined as error
    response = error_condition(DFU_errSTALLED_PKT, request);
  }
  return response;
}

static struct dfu_cmd_response state_dnload_sync(enum dfu_cmd_request request, uint8_t (&?block)[DFU_TRANSFER_SIZE_BYTES], int32_t block_size_bytes) {
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };
  
  if (request == DFU_DEFERRED_ACTION_FLASH_WRITE) {
    struct dfu_sub_response rqst_status = sub_sm_process_dnload(dfu_fifo);
    if (rqst_status.status != DFU_OK) {
      response = error_condition(rqst_status.status, 0);
    } else {
      response.status = DFU_API_SUCCESS;
    }

  } else if (request == DFU_GETSTATUS) {
    int32_t poll_timeout = 0;
    if (isnull(block) || block_size_bytes != DFU_GET_STATUS_PAYLOAD_SIZE_BYTES) {
      response = error_condition(DFU_errUNKNOWN, 0);

    } else {
      if (dfufifo_is_page_ready()) {
        normal_transition(STATE_DFU_DOWNLOAD_BUSY);
        response = normal_transition(STATE_DFU_DOWNLOAD_SYNC);
        response.deferred_request = DFU_DEFERRED_ACTION_FLASH_WRITE;
        poll_timeout = sub_sm_get_poll_timeout();

      } else {
        response = normal_transition(STATE_DFU_DOWNLOAD_IDLE);
      }
    }
    response = build_status(block, poll_timeout, response);

  } else if (request == XMOS_DFU_BUS_RESET) {
    /* fall-through, handle in common command handler */

  } else if (request != DFU_GETSTATE) {
    response = error_condition(DFU_errSTALLED_PKT, request);
  }
  return response;
}

static struct dfu_cmd_response state_manifest_sync(enum dfu_cmd_request request, uint8_t (&?block)[DFU_TRANSFER_SIZE_BYTES], int32_t block_size_bytes) {
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };
  static int32_t flash_finalised = 0;

  if (request == DFU_DEFERRED_ACTION_FLASH_MANIFEST) {
    struct dfu_sub_response rqst_status = sub_sm_process_manifest(dfu_fifo);
    if (rqst_status.status != DFU_OK) {
      response = error_condition(rqst_status.status, 0);
    } else {
      response.status = DFU_API_SUCCESS;
      flash_finalised = rqst_status.flash_finalised;
    }

  } else if (request == DFU_GETSTATUS) {
    int32_t poll_timeout = 0;
    if (isnull(block) || (block_size_bytes != DFU_GET_STATUS_PAYLOAD_SIZE_BYTES)) {
      response = error_condition(DFU_errUNKNOWN, 0);

    } else {
      if (fifo_is_empty(dfu_fifo) && flash_finalised) {
        response = normal_transition(STATE_DFU_IDLE);
        flash_finalised = 0;

      } else {
        response = normal_transition(STATE_DFU_MANIFEST);
        response = normal_transition(STATE_DFU_MANIFEST_SYNC);
        response.deferred_request = DFU_DEFERRED_ACTION_FLASH_MANIFEST;
        poll_timeout = sub_sm_get_poll_timeout();
      }
    }
    response = build_status(block, poll_timeout, response);

  } else if (request == XMOS_DFU_BUS_RESET) {
    /* fall-through, handle in common command handler */

  } else if (request != DFU_GETSTATE) {
    response = error_condition(DFU_errSTALLED_PKT, request);
  }
  return response;
}
static struct dfu_cmd_response state_download_idle(const uint8_t (&?write_block)[DFU_TRANSFER_SIZE_BYTES],
                                                  int32_t block_size_bytes, int32_t &?block_num) {
  // TOTO - use this
  UNUSED(block_num);

  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };
  if (block_size_bytes == 0) {
      response = normal_transition(STATE_DFU_MANIFEST_SYNC);

  } else if (!isnull(write_block)) {
    if (fifo_block_enqueue(dfu_fifo, write_block, block_size_bytes) != FIFO_OK) {
      response = error_condition(DFU_errFILE, 0);
    } else {
      response = normal_transition(STATE_DFU_DOWNLOAD_SYNC);
    }
  }
  return response;
}

static struct dfu_cmd_response state_upload_idle(uint8_t (&?read_block)[DFU_TRANSFER_SIZE_BYTES],
                                                 int32_t block_size_bytes, int32_t &?read_length) {
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };
  if (read_length <= 0) {
    // Terminate read
    response = normal_transition(STATE_DFU_IDLE);
    response.return_data_len = 0;

  } else {
    enum dfu_api_status upload = upload_block(read_block, block_size_bytes);
    if (upload != DFU_API_SUCCESS) {
      response = error_condition(DFU_errFILE, upload);
      
    } else {
      if (read_length < block_size_bytes) {
        response = normal_transition(STATE_DFU_IDLE);
        response.return_data_len = read_length;
        
      } else {
        response.status = DFU_API_SUCCESS;
        response.return_data_len = block_size_bytes;
      }
      read_length -= block_size_bytes;
    }
  }
  return response;
}

struct dfu_cmd_response dfu_request_with_arguments(enum dfu_cmd_request request,
                                                   uint8_t (&?block)[],
                                                   int32_t block_size_bytes,
                                                   int32_t &?block_num)
{
  static int32_t read_length = 0;
  struct dfu_cmd_response response = { DFU_API_BAD_PARAM, 0, 0 };

#if DEBUG_PRINT_ENABLE_DFU
  debug_printf("DFU: %s", request_str(request));
  if (request == DFU_DNLOAD) {
    if (block_size_bytes > 0) {
      debug_printf(" 0x%X %d\n", block_num, block_size_bytes);
    } else {
      debug_printf(" zero-length packet\n");
    }
  } else {
    debug_printf("\n");
  }
#endif

  if ((request == XMOS_DFU_GET_DESCRIPTOR) && (block_size_bytes == DFU_GETDESCRIPTOR_PAYLOAD_SIZE_BYTES)) {
    block[DFU_GETDESCRIPTOR_BCD_DEVICE_INDEX] = (uint8_t)DFU_BCD_DEVICE;
    block[DFU_GETDESCRIPTOR_BCD_DEVICE_INDEX + 1] = (uint8_t)(DFU_BCD_DEVICE >> 8);
    block[DFU_GETDESCRIPTOR_FUNC_ATTRS_INDEX] = (uint8_t)DFU_FUNC_ATTRS;
    block[DFU_GETDESCRIPTOR_MODE_FLAG_INDEX] = (state == STATE_APP_IDLE) ? DFU_MODE_RUNTIME : DFU_MODE_DFU;
    
    response.status = DFU_API_SUCCESS;
    response.return_data_len = DFU_GETDESCRIPTOR_PAYLOAD_SIZE_BYTES;
    response.deferred_request = 0;
    return response;
  }

  // TODO - review return status codes and whether they are compatible with USB DFU spec, ie. whether to stall or not.
  switch (state) {
    case STATE_APP_IDLE:
      response = state_app_idle(request);
      break;

    case STATE_APP_DETACH:
      response = state_detach(request);
      if (response.status == DFU_API_SUCCESS) {
        sub_sm_clear();
      }
      break;

    case STATE_DFU_IDLE:
      if (request == DFU_DNLOAD) {
        response = action_entry_dnload(block, block_size_bytes, block_num);

      } else if (request == DFU_UPLOAD) {
        response = action_entry_upload(block, block_size_bytes, read_length);

      } else {
        response = state_dfu_idle(request);
      }
      break;

    case STATE_DFU_DOWNLOAD_SYNC:
      response = state_dnload_sync(request, block, block_size_bytes);
      break;

    case STATE_DFU_MANIFEST_SYNC:
      response = state_manifest_sync(request, block, block_size_bytes);
      break;

    case STATE_DFU_DOWNLOAD_IDLE:
      if (request == DFU_DNLOAD) {
        response = state_download_idle(block, block_size_bytes, block_num);

      // TODO - add support for abort.

      } else if ((request != DFU_GETSTATUS) && (request != DFU_GETSTATE) && (request != XMOS_DFU_BUS_RESET)) {
        response = error_condition(DFU_errSTALLED_PKT, request);
      }
      break;

    case STATE_DFU_UPLOAD_IDLE:
      if (request == DFU_UPLOAD) {
        response = state_upload_idle(block, block_size_bytes, read_length);

      } else if (request == DFU_ABORT) {
        response = normal_transition(STATE_DFU_IDLE);

      } else if ((request != DFU_GETSTATUS) && (request != DFU_GETSTATE) && (request != XMOS_DFU_BUS_RESET)) {
        // no other requests expected, defined as error
        response = error_condition(DFU_errSTALLED_PKT, request);
      }
      break;

    case STATE_DFU_ERROR:
      if (request == DFU_CLRSTATUS) {
        response = normal_transition(STATE_DFU_IDLE);
        sub_sm_clear();
      }
      break;

    // TODO
    // default:
    //   response = error_condition(DFU_errUNKNOWN, 0);
    //   break;
  }

  /* Handle common requests last */
  if ((request == DFU_GETSTATUS) && !isnull(block) && (block_size_bytes == DFU_GET_STATUS_PAYLOAD_SIZE_BYTES) && (response.status != DFU_API_SUCCESS)) {
    // if get-status was not handled by state machine handlers, handle it here.
    response = build_status(block, 0, response);

  } else if ((request == DFU_GETSTATE) && !isnull(block) && (block_size_bytes == DFU_GET_STATE_PAYLOAD_SIZE_BYTES)) {
    response.status = DFU_API_SUCCESS;
    response.return_data_len = DFU_GET_STATE_PAYLOAD_SIZE_BYTES;
    block[DFU_GETSTATE_INDEX] = state;

  } else if ((request == XMOS_DFU_BUS_RESET) && (response.status != DFU_API_SUCCESS)) {
    // if bus reset was not handled by state machine handlers, handle it here by resetting to app idle.
    // The expectation is that STATE_APP_IDLE and STATE_APP_DETACH will handle bus reset.
    if (state != STATE_APP_IDLE) {
      /* Exit from DFU mode. Send reboot command */
      flash_deinit();
      response = normal_transition(STATE_APP_IDLE);
      response.deferred_request = DFU_DEFERRED_ACTION_REBOOT;

    } else {
      response = normal_transition(STATE_APP_IDLE);
    }

  } else if ((request == DFU_DETACH) && (state == STATE_DFU_ERROR)) {
    // If otherwise unhandled...
    flash_deinit();
    response = normal_transition(STATE_APP_IDLE);
    response.deferred_request = DFU_DEFERRED_ACTION_REBOOT;

  } else {
    /* For other requests, delegate to state machine handlers */
  }

  return response;
}

struct dfu_cmd_response dfu_request(enum dfu_cmd_request request)
{
  return dfu_request_with_arguments(request, null, 0, null);
}

void dfu_bus_reset(void)
{
  dfu_request(XMOS_DFU_BUS_RESET);
}

void dfu_detach(void)
{
  dfu_request(DFU_DETACH);
}

void dfu_timeout_detach(void)
{
  if (state == STATE_APP_DETACH) {
    normal_transition(STATE_APP_IDLE);
  }
  else {
    debug_printf("unexpected detach timeout call\n");
    // remain in current state, no error code indication
  }
}
