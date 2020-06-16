// Copyright (c) 2020, XMOS Ltd, All rights reserved
#include <assert.h>
#include <stdio.h>
#include <stdbool.h>
#include "suffix_verifier.h"

int main(void)
{
  size_t suffix_length;
  int ret;
  char msg[256] = "";
  unsigned char data[] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    0x00, 0x01, 0x00, 0xCD, 0x00, 0xAB, 0x01, 0x10,
    0x55, 0x46, 0x44, 0x10, 0x0A, 0x10, 0x49, 0x53
  };

  ret = verify_dfu_suffix(data, sizeof(data), 0xAB, 0xCD, 0x01,
                          &suffix_length, msg);
  if (ret != 0) {
    printf("error: %s\n", msg);
  }
  assert(ret == 0);
  assert(suffix_length == 16);

  printf("PASS\n");
  return 0;
}
