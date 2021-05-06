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

  // vendor ID entered and matching
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // vendor ID entered and mismatching
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0x00, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // vendor ID entered and ignored
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0xFFFF, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // vendor ID not entered and check skipped
  memcpy(data, template, 32);
  data[20] = 0xFF;
  data[21] = 0xFF;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // vendor ID not entered and ignored
  memcpy(data, template, 32);
  data[20] = 0xFF;
  data[21] = 0xFF;
  ret = verify_dfu_suffix(data, 32, 0xFFFF, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // product ID entered and matching
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // product ID entered and mismatching
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0xAB, 0x00, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // product ID entered and ignored
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xFFFF, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // product ID not entered and check skipped
  memcpy(data, template, 32);
  data[18] = 0xFF;
  data[19] = 0xFF;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // product ID not entered and ignored
  memcpy(data, template, 32);
  data[18] = 0xFF;
  data[19] = 0xFF;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xFFFF, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // bcdDevice entered and matching
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // bcdDevice entered and mismatching
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0xAB, 0x00, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret != 0);

  // bcdDevice entered and ignored
  memcpy(data, template, 32);
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0xFFFF, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // bcdDevice not entered and check skipped
  memcpy(data, template, 32);
  data[16] = 0xFF;
  data[17] = 0xFF;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0x01, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  // bcdDevice not entered and ignored
  memcpy(data, template, 32);
  data[16] = 0xFF;
  data[17] = 0xFF;
  ret = verify_dfu_suffix(data, 32, 0xAB, 0xCD, 0xFFFF, &suffix_length, msg);
  printf("%d\n", ret);
  assert(ret == 0);

  printf("PASS\n");
  return 0;
}
