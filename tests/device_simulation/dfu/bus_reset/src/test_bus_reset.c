// Copyright 2020-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <unity.h>

#include "dfu.h"

static uint8_t payload[DFU_TRANSFER_SIZE_BYTES];

static void get_state_and_check(enum dfu_state expected_state)
{
  struct dfu_cmd_response response = dfu_request_with_arguments(DFU_GETSTATE, payload, DFU_GET_STATE_PAYLOAD_SIZE_BYTES, NULL);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  TEST_ASSERT_EQUAL(expected_state, payload[0]);
}

void test_bus_reset_detach_cycle(void)
{
  get_state_and_check(STATE_APP_IDLE);

  struct dfu_cmd_response response = dfu_request(DFU_DETACH);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_DETACH);

  response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_DFU_IDLE);

  response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_IDLE);
  TEST_ASSERT_EQUAL(DFU_DEFERRED_ACTION_REBOOT, response.deferred_request);
}

void test_repeated_bus_resets_stays_in_app_idle(void)
{
  get_state_and_check(STATE_APP_IDLE);

  struct dfu_cmd_response response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_IDLE);

  response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_IDLE);
}

void test_usb_dfu_mode_entry(void)
{
  get_state_and_check(STATE_APP_IDLE);

  int32_t dfu_mode = 1;

  struct dfu_cmd_response response = dfu_request_with_arguments(XMOS_DFU_BUS_RESET, NULL, 0, &dfu_mode);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_DFU_IDLE);

  // bus-reset with dfu-mode set should not cause transition back to app idle
  response = dfu_request_with_arguments(XMOS_DFU_BUS_RESET, NULL, 0, &dfu_mode);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_DFU_IDLE);
  
  // bus-reset with dfu-mode cleared should not cause transition back to app idle
  dfu_mode = 0;
  response = dfu_request_with_arguments(XMOS_DFU_BUS_RESET, NULL, 0, &dfu_mode);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_IDLE);
}
