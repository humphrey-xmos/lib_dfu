// Copyright 2019-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <unity.h>

#include "dfu.h"

static uint8_t payload[DFU_TRANSFER_SIZE_BYTES];

static void get_state_and_check(enum dfu_state expected_state)
{
  struct dfu_cmd_response response = dfu_request_with_arguments(DFU_GETSTATE, payload, DFU_GET_STATE_PAYLOAD_SIZE_BYTES, NULL);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  TEST_ASSERT_EQUAL_UINT8(expected_state, payload[DFU_GETSTATE_INDEX]);
}

static void get_status_and_check(enum dfu_status expected_status, enum dfu_state expected_state)
{
  struct dfu_cmd_response response = dfu_request_with_arguments(DFU_GETSTATUS, payload, DFU_GET_STATUS_PAYLOAD_SIZE_BYTES, NULL);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  TEST_ASSERT_EQUAL_UINT8(expected_status, payload[DFU_GETSTATUS_STATUS_INDEX]);
  TEST_ASSERT_EQUAL_UINT8(expected_state, payload[DFU_GETSTATUS_STATE_INDEX]);
}

void test_detach(void)
{
  get_state_and_check(STATE_APP_IDLE);

  struct dfu_cmd_response response = dfu_request(DFU_DETACH);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_status_and_check(DFU_OK, STATE_APP_DETACH);

  response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_status_and_check(DFU_OK, STATE_DFU_IDLE);
  
  // Return State machine to App idle
  response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_status_and_check(DFU_OK, STATE_APP_IDLE);
}

void test_detach_from_dfuidle_returns_to_app_idle(void)
{
  get_state_and_check(STATE_APP_IDLE);

  struct dfu_cmd_response response = dfu_request(DFU_DETACH);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_DETACH);

  response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_DFU_IDLE);

  response = dfu_request(DFU_DETACH);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_IDLE);
  TEST_ASSERT_EQUAL(DFU_DEFERRED_ACTION_REBOOT, response.deferred_request);
}

void test_detach_from_error(void)
{
  get_state_and_check(STATE_APP_IDLE);

  struct dfu_cmd_response response = dfu_request(DFU_DETACH);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_DETACH);

  response = dfu_request(XMOS_DFU_BUS_RESET);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_DFU_IDLE);

  // Trigger error state by sending invalid DNLOAD request
  response = dfu_request_with_arguments(DFU_DNLOAD, payload, 0, NULL);
  TEST_ASSERT_EQUAL(DFU_API_ERROR, response.status);

  response = dfu_request(DFU_DETACH);
  TEST_ASSERT_EQUAL(DFU_API_SUCCESS, response.status);
  get_state_and_check(STATE_APP_IDLE);
  TEST_ASSERT_EQUAL(DFU_DEFERRED_ACTION_REBOOT, response.deferred_request);
}
