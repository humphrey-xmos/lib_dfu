// Copyright 2020-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>
#include <stdbool.h>
#ifdef __xcore__
#include <string.h>
#else
#include <memory.h>
#include <time.h>
#endif
#include <stdint.h>
#include <errno.h>

// byte order portability
#ifdef _WIN32
#define htole16(x) (x) // Windows little endian only
#define le32toh(x) (x)
#elif __APPLE__
#include <libkern/OSByteOrder.h>
#define htole16(x) OSSwapHostToLittleInt16(x)
#define le32toh(x) OSSwapLittleToHostInt32(x)
#elif __xcore__
#define htole16(x) (x) // XCore is little endian
#define le32toh(x) (x)
#else
#include <endian.h>
#endif

#include "app_types.h"
#include "labels.h"
#include "dfu_utils.h"
#include "hal.h"
#include "input_reader.h"
#include "operations.h"

extern bool quiet;
extern bool verbose;

static int check_state(enum dfu_state expected)
{
  uint8_t payload[DFU_GET_STATE_PAYLOAD_SIZE_BYTES];

  if (hal_read_command(DFU_GETSTATE, payload, sizeof(payload)) != sizeof(payload)) {
    return 1;
  }
  enum dfu_state state = (enum dfu_state)payload[DFU_GETSTATE_INDEX];

  if (state == STATE_DFU_ERROR) {
    PRINT_ERROR("Device in dfu ERROR state\n");
    
    uint8_t payload_status[DFU_GET_STATUS_PAYLOAD_SIZE_BYTES];

    struct dfu_getstatus getstatus = { 0 };
    if (hal_read_command(DFU_GETSTATUS, payload_status, sizeof(payload_status)) == sizeof(payload_status)) {
      getstatus.status = (enum dfu_status)le32toh(payload_status[DFU_GETSTATUS_STATUS_INDEX]);
      PRINT_ERROR("Status %s\n", status_str(getstatus.status));
    }

    PRINT_ERROR("Send CLRSTATUS to attempt recovery\n");
    hal_write_command(DFU_CLRSTATUS, NULL, 0);
    return 2;
  }

  if (state != expected) {
    PRINT_ERROR("Device state is %s (%d), expected %s (%d)\n", state_str(state), state, state_str(expected), expected);
    return 3;
  }

  return 0;
}

static int check_status(struct dfu_getstatus *getstatus)
{
  uint8_t payload[DFU_GET_STATUS_PAYLOAD_SIZE_BYTES];
  if (hal_read_command(DFU_GETSTATUS, payload, sizeof(payload)) != sizeof(payload)) {
    return 1;
  }

  // convert from hard little endian order after deserialization
  getstatus->state = payload[DFU_GETSTATUS_STATE_INDEX];
  getstatus->status = payload[DFU_GETSTATUS_STATUS_INDEX];
  getstatus->poll_timeout_msec = (unsigned int)(payload[DFU_GETSTATUS_POLL_TIMEOUT_INDEX] | (payload[DFU_GETSTATUS_POLL_TIMEOUT_INDEX + 1] << 8) | (payload[DFU_GETSTATUS_POLL_TIMEOUT_INDEX + 2] << 16));

  if (getstatus->status != DFU_OK) {
    PRINT_ERROR("Status was %s when %s expected\n", status_str(getstatus->status), status_str(DFU_OK));

    PRINT_ERROR("State %s (%d)\n", state_str(getstatus->state), getstatus->state);

    PRINT_ERROR("Send CLRSTATUS to attempt recovery\n");
    hal_write_command(DFU_CLRSTATUS, NULL, 0);
    return 2;
  }

  static unsigned last_timeout = UINT32_MAX;
  if (verbose) {
    if (getstatus->poll_timeout_msec != last_timeout) {
      last_timeout = getstatus->poll_timeout_msec;
      printf("new poll timeout %u msec\n", getstatus->poll_timeout_msec);
    }
  }

  return 0;
}

static void fetch_descriptor(void)
{
  uint8_t descriptor_payload[DFU_GETDESCRIPTOR_PAYLOAD_SIZE_BYTES];
  if (hal_read_command(XMOS_DFU_GET_DESCRIPTOR, descriptor_payload, DFU_GETDESCRIPTOR_PAYLOAD_SIZE_BYTES) != DFU_GETDESCRIPTOR_PAYLOAD_SIZE_BYTES) {
    printf("Fetch descriptor failed\n");

  } else if (!quiet) {
    printf("device descriptor: bcdDevice 0x%04X, bmAttributes 0x%02X, mode 0x%02X (%s)\n",
           le32toh((descriptor_payload[DFU_GETDESCRIPTOR_BCD_DEVICE_INDEX + 1] << 8) | descriptor_payload[DFU_GETDESCRIPTOR_BCD_DEVICE_INDEX]),
           descriptor_payload[DFU_GETDESCRIPTOR_FUNC_ATTRS_INDEX],
           descriptor_payload[DFU_GETDESCRIPTOR_MODE_FLAG_INDEX],
           descriptor_payload[DFU_GETDESCRIPTOR_MODE_FLAG_INDEX] == DFU_MODE_DFU ? "DFU" : "Runtime");
  }
}

int detach_and_bus_reset(void)
{
  if (verbose) {
    printf("detach and bus reset\n");
  }

  if (check_state(STATE_APP_IDLE) == 0) {
    
    fetch_descriptor();

    if (hal_write_command(DFU_DETACH, NULL, 0) != 0) {
      return 2;
    }

    if (check_state(STATE_APP_DETACH) != 0) {
      return 3;
    }

    if (hal_reboot() != APP_OK) {
      return 4;
    }

  } else {
    if (hal_write_command(DFU_ABORT, NULL, 0) != 0) {
      return 6;
    }
  }

  if (check_state(STATE_DFU_IDLE) != 0) {
    return 7;
  }

  if (!quiet) {
    printf("detach and bus reset successful\n");
  }

  fetch_descriptor();

  return 0;
}

static void get_profile_data(void) {
  if (!quiet) {
    uint8_t payload[sizeof(struct dfu_profile_data)];
    printf("profile data size: %zu\n", sizeof(struct dfu_profile_data));
    if (hal_read_command(XMOS_DFU_GETPROFILE, payload, sizeof(struct dfu_profile_data)) != sizeof(struct dfu_profile_data)) {
      printf("get profile failed\n");
    } else {
      struct dfu_profile_data *profile = (struct dfu_profile_data *)payload;
      printf("profile data: %u, %u/%u, %u\n", profile->command_time, profile->command_index, profile->index_total, profile->cmd);
    }
  }
}

static int download_file(const unsigned char *bytes, size_t length, unsigned block_size)
{
  size_t byte_count = 0;
  unsigned block_count = 0;
  struct dfu_getstatus getstatus;

  if (verbose) {
    printf("start download of %d bytes, block size %d\n", (int)length, block_size);
  }

  while (byte_count < length) {
    size_t block_bytes = block_size;
    if (length - byte_count < block_size) {
      block_bytes = length - byte_count;
    }

    if (!quiet) {
      printf("download block %u, %d bytes, %02X\n", block_count, (int)block_bytes, bytes[byte_count + block_size - 1]);
    }

    if (hal_write_command(DFU_DNLOAD, &bytes[byte_count], block_bytes) != (int)block_bytes) {
      return 1;
    }

    do {
      if (check_status(&getstatus) != 0) {
        return 2;
      }

      if (getstatus.state == STATE_DFU_DOWNLOAD_IDLE && getstatus.poll_timeout_msec != 0) {
        printf("Warning: unexpected non-zero timeout when in Download idle: %d ms\n", getstatus.poll_timeout_msec);
      }
      if (getstatus.state == STATE_DFU_DOWNLOAD_BUSY && getstatus.poll_timeout_msec == 0) {
        printf("Warning: unexpected zero timeout when in Download busy: %d ms\n", getstatus.poll_timeout_msec);
      }

      sleep_milliseconds(getstatus.poll_timeout_msec);
    } while (getstatus.state == STATE_DFU_DOWNLOAD_BUSY);

    if (check_state(STATE_DFU_DOWNLOAD_IDLE) != 0) {
      return 3;
    }

    block_count++;
    byte_count += block_bytes;
  }

  if (hal_write_command(DFU_DNLOAD, NULL, 0) != 0) {
    return 4;
  }

  do {
    if (check_status(&getstatus) != 0) {
      return 5;
    }

    sleep_milliseconds(getstatus.poll_timeout_msec);
  } while (getstatus.state == STATE_DFU_MANIFEST);

  if (check_state(STATE_DFU_IDLE) != 0) {
    return 6;
  }

  get_profile_data();

  return APP_OK;
}

int write_upgrade(struct inputs inputs, unsigned block_size)
{
  if (verbose) {
    printf("write upgrade %d boot bytes\n", (int)inputs.boot.length);
  }

  if (detach_and_bus_reset() != 0) {
    return 1;
  }

  if (!quiet) {
    printf("upgrading: image size %d bytes, block size %d, num blocks %d, tail %d bytes\n",
      (int)inputs.boot.length, block_size, (((unsigned)inputs.boot.length + block_size - 1U) / block_size), ((unsigned)inputs.boot.length % block_size));
    }

  if (download_file(inputs.boot.bytes, inputs.boot.length, block_size) != 0) {
    return 2;
  }

  printf("write upgrade successful\n");

  return APP_OK;
}

static uint8_t sector_buffer[4096];

static int upload_file(FILE *handle, unsigned block_size)
{
  unsigned returned_length = block_size;
  size_t byte_count = 0;
  unsigned block_count = 0;

  if (handle == NULL) {
    return APP_BAD_PARAM;
  }

  while (returned_length == block_size) {
    returned_length = 0;
    
    int read_status = hal_read_command(DFU_UPLOAD, &sector_buffer[byte_count], block_size);
    if (read_status == (int)block_size) {
      returned_length = block_size;
      if (!quiet) {
        printf("upload block %u, %u bytes, %02X\n", block_count, block_size, sector_buffer[byte_count + block_size - 1]);
      }

      byte_count += block_size;
      block_count += 1;

      if (byte_count >= sizeof(sector_buffer)) {
        if (fwrite(sector_buffer, 1, sizeof(sector_buffer), handle) != sizeof(sector_buffer)) {
          PRINT_ERROR("Problem writing file (errno %d)\n", errno);
          return APP_BAD_COMMS;
        }
        byte_count = 0;
      }

    } else if (read_status >= 0) {
      // Normal, short read, exit
      unsigned extra = (unsigned)read_status;
      returned_length = extra;

      if (!quiet) {
        printf("short-read: upload block %u, %u bytes, %02X\n", block_count, extra, sector_buffer[byte_count + block_size - 1]);

        printf("upload total: %u bytes\n", (block_count * block_size) + extra);
      }
      // TODO - merge this with write above
      byte_count += extra;

      if (fwrite(sector_buffer, 1, byte_count, handle) != byte_count) {
        PRINT_ERROR("Problem writing file (errno %d)\n", errno);
        return APP_BAD_COMMS;
      }

    } else {
      printf("ERROR: upload block %u, status %d\n", block_count, read_status);
      return APP_ERROR;
    }

  }
  
  get_profile_data();

  return APP_OK;
}

int read_upload(const char *file_name, unsigned block_size)
{
  if ((file_name == NULL) || (block_size == 0)) {
    return APP_BAD_PARAM;
  }
  if (verbose) {
    printf("read upload, using block %d bytes\n", block_size);
  }

  if (detach_and_bus_reset() != 0) {
    return APP_BAD_COMMS;
  }

  // TODO - create temp file to write during upload process
  FILE *handle = fopen(file_name, "wb");
  if (handle == NULL) {
    PRINT_ERROR("Problem opening file %s\n", file_name);
    return APP_ERROR;
  }

  if (upload_file(handle, block_size) != APP_OK) {
    fclose(handle);
    return APP_ERROR;
  }
  fclose(handle);

  printf("upload read successful\n");

  return APP_OK;
}
