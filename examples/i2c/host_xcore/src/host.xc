// Copyright 2016-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <syscall.h>
#include <assert.h>
#include <timer.h>
#include <string.h>

#include "control.h"
#include "dfu.h"
#include "dfu_utils.h"
#include "i2c.h"
#include "control_host.h"
#include "resource.h"
#include "xassert.h"

port p_scl = on tile[0]: XS1_PORT_1N; // Can be accessed via signal SCL_3V3, TP13
port p_sda = on tile[0]: XS1_PORT_1O; // Can be accessed via signal SDA_3V3, TP14

#define GET_STATE_LENGTH_BYTES (4 + DFU_GET_STATE_PAYLOAD_SIZE_BYTES) // sizeof(struct dfu_dnload_header) + 1 byte for state
#define GET_STATUS_LENGTH_BYTES (4 + DFU_GET_STATUS_PAYLOAD_SIZE_BYTES)

int host_getState(client interface i2c_master_if i_i2c, uint8_t *state)
{
  uint8_t payload[GET_STATE_LENGTH_BYTES];
  int ctrl = control_read_command(RESOURCE_ID_DFU, CONTROL_CMD_SET_READ(DFU_GETSTATE), i_i2c, payload, GET_STATE_LENGTH_BYTES);
  if (ctrl != CONTROL_SUCCESS) {
    printf("control read state command failed with %d\n", ctrl);
    return 1;
  }
  *state = payload[4];
  return 0;
}

int host_getStatus(client interface i2c_master_if i_i2c, uint8_t *status, uint8_t *nextState, unsigned int *timeout, uint8_t *strIndex)
{
  UNUSED(strIndex);

  uint8_t payload[GET_STATUS_LENGTH_BYTES];
  int ctrl = control_read_command(RESOURCE_ID_DFU, CONTROL_CMD_SET_READ(DFU_GETSTATUS), i_i2c, payload, GET_STATUS_LENGTH_BYTES);
  if (ctrl != CONTROL_SUCCESS) {
    printf("control read status command failed with %d\n", ctrl);
    return 1;
  }
  *status = payload[4 + DFU_GETSTATUS_STATUS_INDEX];
  *timeout = 0;
  memcpy(timeout, &payload[4 + DFU_GETSTATUS_POLL_TIMEOUT_INDEX], DFU_GETSTATUS_POLL_TIMEOUT_BYTES);
  *nextState = payload[4 + DFU_GETSTATUS_STATE_INDEX];
  // *strIndex = payload[4 + DFU_GETSTATUS_STRINDEX_INDEX];
  return 0;
}

int host_upload(client interface i2c_master_if i_i2c, uint8_t *payload, int32_t length)
{
  int ctrl = control_read_command(RESOURCE_ID_DFU, CONTROL_CMD_SET_READ(DFU_UPLOAD), i_i2c, payload, length);
  if (ctrl != CONTROL_SUCCESS) {
    printf("control read upload command failed with %d\n", ctrl);
    return 1;
  }
  return 0;
}

int host_request(client interface i2c_master_if i_i2c, enum dfu_cmd_request request)
{
  uint8_t payload[4] = { 0 };
  int ctrl = control_write_command(RESOURCE_ID_DFU, CONTROL_CMD_SET_WRITE(request), i_i2c, payload, 4);
  if (ctrl != CONTROL_SUCCESS) {
    printf("control write command %d failed with %d\n", request, ctrl);
    return 1;
  }
  return 0;
}

int main(void)
{
  i2c_master_if i_i2c[1];
  par {
    on tile[0]: {
      i2c_master(i_i2c, 1, p_scl, p_sda, 100);
    }
    on tile[1]: {
      control_version_t version;
      uint8_t payload[4];
      int i;

      if (control_init_i2c(DEVICE_I2C_ADDRESS) != CONTROL_SUCCESS) {
        printf("control init failed\n");
        exit(1);
      }

      printf("i2c ready\n");

      if (control_query_version(&version, i_i2c[0]) != CONTROL_SUCCESS) {
        printf("control query version failed\n");
        exit(1);
      }
      if (version != CONTROL_VERSION) {
        printf("version expected 0x%X, received 0x%X\n", CONTROL_VERSION, version);
      }

      printf("Starting Control DFU example\n");

      /* DFU endpoint access */
      host_getState(i_i2c[0], &payload[0]);
      printf("DFU state: %d\n", payload[0]);

      unsigned int timeout;
      uint8_t state;
      uint8_t status;
      host_getStatus(i_i2c[0], &status, &state, &timeout, NULL);
      printf("DFU status: %d, timeout: %d ms, next state: %d\n", status, timeout, state);

      host_request(i_i2c[0], DFU_DETACH);
      printf("Sent detach command\n");

      host_getStatus(i_i2c[0], &status, &state, &timeout, NULL);
      printf("DFU status: %d, timeout: %d ms, next state: %d\n", status, timeout, state);

      host_request(i_i2c[0], XMOS_DFU_BUS_RESET);
      printf("Sent bus reset command\n");

      host_getStatus(i_i2c[0], &status, &state, &timeout, NULL);
      printf("DFU status: %d, timeout: %d ms, next state: %d\n", status, timeout, state);

      host_request(i_i2c[0], XMOS_DFU_BUS_RESET);
      printf("Sent bus reset command\n");

      /* Allow device to reboot */
      sleep_milliseconds(1000);

      host_getStatus(i_i2c[0], &status, &state, &timeout, NULL);
      printf("DFU status: %d, timeout: %d ms, next state: %d\n", status, timeout, state);

      printf("Starting Control data example\n");
      /* Data endpoint exchange */
      for (i = 0; i < 4; i++) {
        payload[0] = i;
        if (control_write_command(RESOURCE_ID, CONTROL_CMD_SET_WRITE(0), i_i2c[0], payload, 1) != CONTROL_SUCCESS) {
          printf("control write command failed\n");
          exit(1);
        }

        sleep_milliseconds(1000);

        if (control_read_command(RESOURCE_ID, CONTROL_CMD_SET_READ(0), i_i2c[0], payload, 1) != CONTROL_SUCCESS) {
          printf("control read command failed\n");
          exit(1);
        }

        sleep_milliseconds(1000);

        if (payload[0] != i) {
          printf("control read command returned the wrong value, expected %d, returned %d\n", i, payload[0]);
          exit(1);
        }
        printf("Written and read back command with payload: 0x%02X\n", payload[0]);
      }

      control_cleanup_i2c();
      printf("done\n");
      exit(0);
    }
  }
  return 0;
}
