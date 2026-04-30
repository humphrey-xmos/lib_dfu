// Copyright 2020-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include "hal.h"

#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#include "app_types.h"
#include "control_host.h"
#include "device_id.h"
#include "dfu_utils.h"
#include "labels.h"

extern bool quiet;
extern bool verbose;

#define RESET_TIMEOUT_MSEC 1000

static uint8_t buffer[256];

#if CONTROL_USE_I2C && __xcore__
int hal_connect(struct device_id device_id, CLIENT_INTERFACE(i2c_master_if, i_i2c))
#else
int hal_connect(struct device_id device_id)
#endif
{
  const int shift = 0;
  if (control_init_i2c(device_id.i2c_address << shift) != CONTROL_SUCCESS) {
    PRINT_ERROR("Control initialisation over I2C failed\n");
    return APP_ERROR;
  }
  if (verbose) {
    printf("I2C connected (slave address 0x%X)\n", device_id.i2c_address);
  }

  control_version_t version;
#if CONTROL_USE_I2C && __xcore__
  if (control_read_command(CONTROL_SPECIAL_RESID, CONTROL_GET_VERSION, i_i2c, &version, sizeof(control_version_t)) != CONTROL_SUCCESS)
#else
  if (control_read_command(CONTROL_SPECIAL_RESID, CONTROL_GET_VERSION, &version, sizeof(control_version_t)) != CONTROL_SUCCESS)
#endif
  {
    PRINT_ERROR("Control query version failed\n");
    return APP_BAD_COMMS;
  }
  if (version != CONTROL_VERSION) {
    PRINT_ERROR("Mismatch of the control version between host and device. Expected 0x%X, received 0x%X\n", CONTROL_VERSION, version);
    return APP_WARNING;
  }
  if (verbose) {
    printf("control version query successful\n");
  }

  return APP_OK;
}

#if CONTROL_USE_I2C && __xcore__
int hal_read_command(int command, unsigned char payload[], size_t num_bytes, CLIENT_INTERFACE(i2c_master_if, i_i2c))
#else
int hal_read_command(int command, unsigned char payload[], size_t num_bytes)
#endif
{
  if (verbose) {
    printf("HAL: read command: %s (%d), %zu bytes\n", command_str(command), command, num_bytes);
  }
  if (payload == NULL && num_bytes > 0) {
    PRINT_ERROR("Payload pointer is NULL for non-zero payload length\n");
    return APP_BAD_PARAM;
  }
  if (num_bytes > (sizeof(buffer) - sizeof(struct dfu_upload_header))) {
    PRINT_ERROR("Requested read size %zu is too large. Maximum supported is %zu bytes\n", num_bytes, (sizeof(buffer) - sizeof(struct dfu_upload_header)));
    return APP_ERROR;
  }

#if CONTROL_USE_I2C && __xcore__
  if (control_read_command(RESOURCE_ID_DFU, CONTROL_CMD_SET_READ(command), i_i2c, buffer, (num_bytes + sizeof(struct dfu_upload_header))) != CONTROL_SUCCESS)
#else
  if (control_read_command(RESOURCE_ID_DFU, CONTROL_CMD_SET_READ((control_cmd_t)command), buffer, (num_bytes + sizeof(struct dfu_upload_header))) != CONTROL_SUCCESS)
#endif
  {
    PRINT_ERROR("Control read command did not return success\n");
    return APP_BAD_COMMS;
  }
  /* Options for read are variable length packet, including zero-length, always with header, */
  struct dfu_upload_header header;
  memcpy(&header, buffer, sizeof(header));
  memcpy(payload, buffer + sizeof(header), num_bytes);

  return header.read_length;
}

#if CONTROL_USE_I2C && __xcore__
int hal_write_command(int command, const unsigned char payload[], size_t num_bytes, CLIENT_INTERFACE(i2c_master_if, i_i2c))
#else
int hal_write_command(int command, const unsigned char payload[], size_t num_bytes)
#endif
{
  static uint16_t block_num = 0;

  if (verbose) {
    printf("HAL: write command: %s (%d), %zu bytes\n", command_str(command), command, num_bytes);
  }
  if (num_bytes != 0 && payload == NULL) {
    PRINT_ERROR("Payload pointer is NULL for non-zero payload length\n");
    return APP_BAD_PARAM;
  }
  size_t payload_bytes = 0;

  if (num_bytes > ((sizeof(buffer) - sizeof(struct dfu_dnload_header)))) {
    PRINT_ERROR("Payload size %zu is too large. Maximum supported is %zu bytes\n", num_bytes, (sizeof(buffer) - sizeof(struct dfu_dnload_header)));
    return APP_ERROR;

  } else if (num_bytes != 0)  {
    /* Options for write include; Zero length with no header, or, 'non-zero' length with header, */
    struct dfu_dnload_header header = { 0, 0 };
    header.block_num = ++block_num;

    payload_bytes = num_bytes + sizeof(header);
    memcpy(buffer, &header, sizeof(header));
    if (num_bytes > 0) {
      memcpy(buffer + sizeof(header), payload, num_bytes);
    }
  }

#if CONTROL_USE_I2C && __xcore__
  if (control_write_command(RESOURCE_ID_DFU, CONTROL_CMD_SET_WRITE(command), i_i2c, buffer, payload_bytes) != CONTROL_SUCCESS)
#else
  if (control_write_command(RESOURCE_ID_DFU, CONTROL_CMD_SET_WRITE((control_cmd_t)command), buffer, payload_bytes) != CONTROL_SUCCESS)
#endif
  {
    PRINT_ERROR("Control write command did not return success\n");
    return APP_BAD_COMMS;
  }

  return (int)num_bytes;
}

#if CONTROL_USE_I2C && __xcore__
int hal_reboot(CLIENT_INTERFACE(i2c_master_if, i_i2c))
{
  if (verbose) {
    printf("HAL: reboot\n");
  }

  if (hal_write_command(XMOS_DFU_BUS_RESET, NULL, 0, i_i2c) != 0) {
    /* Allow device turn-around time after reboot */
    sleep_milliseconds(RESET_TIMEOUT_MSEC);
    return APP_BAD_COMMS;
  }
  /* Allow device turn-around time after reboot */
  sleep_milliseconds(RESET_TIMEOUT_MSEC);

  return APP_OK;
}
#else
int hal_reboot(void)
{
  if (verbose) {
    printf("HAL: reboot\n");
  }

  if (hal_write_command(XMOS_DFU_BUS_RESET, NULL, 0) != 0) {
    /* Allow device turn-around time after reboot */
    sleep_milliseconds(RESET_TIMEOUT_MSEC);
    return APP_BAD_COMMS;
  }

  /* Allow device turn-around time after reboot */
  sleep_milliseconds(RESET_TIMEOUT_MSEC);

  return APP_OK;
}
#endif

#if CONTROL_USE_I2C && __xcore__
int hal_revert_factory(CLIENT_INTERFACE(i2c_master_if, i_i2c))
#else
int hal_revert_factory(void)
#endif
{
  if (verbose) {
    printf("HAL: revert factory\n");
  }

  if (hal_write_command(XMOS_DFU_REVERTFACTORY, NULL, 0) != 0) {
    /* Allow time for deferred task to action the revert request */
    sleep_milliseconds(RESET_TIMEOUT_MSEC);
    return APP_BAD_COMMS;
  }
  /* Allow time for deferred task to action the revert request */
  sleep_milliseconds(RESET_TIMEOUT_MSEC);
  return APP_OK;
}

int hal_disconnect(void)
{
  if (control_cleanup_i2c() != CONTROL_SUCCESS) {
    return APP_WARNING;
  }

  return APP_OK;
}
