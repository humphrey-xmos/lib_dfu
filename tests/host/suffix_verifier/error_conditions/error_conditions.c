// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <assert.h>
#include <stdio.h>
#include <memory.h>
#include "suffix_verifier.h"

int main(void)
{
  size_t suffix_length;
  int ret;
  char msg[256] = "";
  unsigned char template[32] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    0x00, 0x01, 0x00, 0xCD, 0x00, 0xAB, 0x01, 0x10,
    0x55, 0x46, 0x44, 0x10, 0x0A, 0x10, 0x49, 0x53
  };
  unsigned char data[32];

  // input too short
  ret = verify_dfu_suffix(data, 1, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // bad CRC
  memcpy(data, template, 32);
  data[31] = 0x00;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // bad suffix length field
  memcpy(data, template, 32);
  data[27] = 0x00;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // bad signature field
  memcpy(data, template, 32);
  data[26] = 0x00;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // bad specification number
  memcpy(data, template, 32);
  data[23] = 0x00;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // bad vendor ID
  memcpy(data, template, 32);
  data[21] = 0x00;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // bad product ID
  memcpy(data, template, 32);
  data[19] = 0x00;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // bad bcdDevice
  memcpy(data, template, 32);
  data[17] = 0x00;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  printf("PASS\n");
  return 0;
}
