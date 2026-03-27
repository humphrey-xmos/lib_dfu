// Copyright 2020-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdbool.h>
#include <memory.h>
#include <errno.h>
#include "suffix_verifier.h"
#include "device_id.h"
#include "input_reader.h"
#include "dfu_utils.h"

extern bool quiet;
extern bool verbose;

static size_t file_size(FILE *handle, const char *name)
{
  if (handle == NULL) {
    return 0;
  }

  if (fseek(handle, 0, SEEK_END) != 0) {
    PRINT_ERROR("fseek failed on %s (errno %d)\n", name, errno);
    return 0;
  }

  long length = ftell(handle);

  if (fseek(handle, 0, SEEK_SET) != 0) {
    PRINT_ERROR("fseek failed on %s (errno %d)\n", name, errno);
    return 0;
  }

  return (size_t)length;
}

static size_t verify_suffix(const unsigned char *bytes, size_t num_bytes, struct device_id device_id)
{
  size_t suffix_length = 0;
  char msg[256];
  int ret;

  ret = verify_dfu_suffix(bytes, num_bytes, device_id.vendor, device_id.product, device_id.bcddevice, &suffix_length, msg);
  if (ret != SUFFIX_OK) {
    PRINT_ERROR("Failed DFU suffix verification (code %d): %s\n", ret, msg);
    return 0;
  }

  return num_bytes - suffix_length;
}

static size_t load_file(const char *file_name, unsigned char **bytes)
{
  if (file_name == NULL) {
    return 0;
  }

  FILE *handle = fopen(file_name, "rb");

  if (handle == NULL) {
    PRINT_ERROR("Problem opening file %s\n", file_name);
    return 0;
  }
  size_t length = file_size(handle, file_name);
  if (length == 0) {
    PRINT_ERROR("Problem finding file length for file %s\n", file_name);
    fclose(handle);
    return 0;
  }

  *bytes = malloc(length + 1);
  if (*bytes == NULL) {
    PRINT_ERROR("Problem allocating memory of %zu bytes\n", length);
    fclose(handle);
    return 0;
  } else {
    if (fread(*bytes, 1, length, handle) != length) {
      PRINT_ERROR("Problem reading file %s (errno %d)\n", file_name, errno);
      fclose(handle);
      return 0;
    }
  }

  fclose(handle);

  if (verbose) {
    printf("opened %s, %lu bytes\n", file_name, length);
  }

  return length;
}

struct inputs read_write_upgrade_inputs(const char *boot_file_name, struct device_id device_id)
{
  struct inputs inputs = { 0 };
  inputs.boot.length = load_file(boot_file_name, &inputs.boot.bytes);
  inputs.boot.length = verify_suffix(inputs.boot.bytes, inputs.boot.length, device_id);
  return inputs;
}

void cleanup_inputs(struct inputs *inputs)
{
  if (inputs->boot.bytes != NULL) {
    free(inputs->boot.bytes);
    inputs->boot.bytes = NULL;
  }
  inputs->boot.length = 0;
}
