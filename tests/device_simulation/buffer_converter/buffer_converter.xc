// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <print.h>

#define DEBUG_UNIT TEST
#define DEBUG_PRINT_ENABLE_TEST 0
#include "debug_print.h"

#define XASSERT_ENABLE_DEBUG 1
#define XASSERT_ENABLE_LINE_NUMBERS 1
#include "xassert.h"

#include "dfu_buffer_converter.h"

void random_sequence(char seq[], int length)
{
  for (int i = 0; i < length; i++) {
    unsigned x;
    crc32(x, -1, 0xEB31D82E);
    seq[i] = x;
  }
}

void test_partial_block(struct buffer_converter &converter,
                        int block_size, int page_size, int tail_size)
{
  char generated[BUFFER_CONVERTER_QUEUE_SIZE_BYTES];
  char block[BUFFER_CONVERTER_QUEUE_SIZE_BYTES];
  char page[BUFFER_CONVERTER_QUEUE_SIZE_BYTES];
  int ret;

  debug_printf("- %d -> %d (%d)\n", block_size, page_size, tail_size);

  random_sequence(generated, tail_size);
  for (int i = tail_size; i < block_size; i++) {
    generated[i] = 0;
  }

  int whole_block_count = tail_size / block_size;
  int partial_block_size = tail_size % block_size;

  for (int i = 0; i < whole_block_count; i++) {
    for (int j = 0; j < block_size; j++) {
      block[j] = generated[i * block_size + j];
    }
    ret = buffer_converter_push(converter, block, block_size);
    assert(ret == 0);
  }
  for (int j = 0; j < partial_block_size; j++) {
    block[j] = generated[whole_block_count * block_size + j];
  }
  ret = buffer_converter_push(converter, block, partial_block_size);
  assert(ret == 0);

  int whole_page_count = tail_size / page_size;
  int partial_page_size = tail_size % page_size;

  for (int i = 0; i < whole_page_count; i++) {
    ret = buffer_converter_pull(converter, page, page_size);
    assert(ret == 0);
    for (int j = 0; j < page_size; j++) {
      if (page[j] != generated[i * page_size + j]) {
        debug_printf("tail page offset %d mismatch: %02X %02X\n",
          i * page_size + j, page[j], generated[i * page_size + j]);
        assert(0);
      }
    }
  }
  ret = buffer_converter_pull(converter, page, page_size);
  assert(ret == 1);
  ret = buffer_converter_padded_pull(converter, page, page_size);
  assert(ret == partial_page_size);
  for (int j = 0; j < partial_page_size; j++) {
    if (page[j] != generated[whole_page_count * page_size + j]) {
      debug_printf("tail page offset %d mismatch: %02X %02X\n",
        whole_page_count * page_size + j, page[j],
        generated[whole_page_count * page_size + j]);
      assert(0);
    }
  }
  for (int j = partial_page_size; j < page_size; j++) {
    if (page[j] != 0) {
      debug_printf("tail page offset %d mismatch: %02X %02X\n",
        whole_page_count * page_size + j, page[j], 0);
      assert(0);
    }
  }
}

void test_whole_blocks(struct buffer_converter &converter,
                       int block_size, int page_size, int repeats)
{
  char generated[BUFFER_CONVERTER_QUEUE_SIZE_BYTES];
  char block[BUFFER_CONVERTER_QUEUE_SIZE_BYTES];
  char page[BUFFER_CONVERTER_QUEUE_SIZE_BYTES];
  int ret;

  debug_printf("+ %d x (%d -> %d)\n", repeats, block_size, page_size);

  if (block_size > page_size) { // large blocks (multiple pages per block)
    int multiplier = block_size / page_size;
    for (int k = 0; k < repeats; k++) {
      random_sequence(generated, block_size);
      for (int i = 0; i < block_size; i++) {
        block[i] = generated[i];
      }
      ret = buffer_converter_push(converter, block, block_size);
      assert(ret == 0);
      for (int j = 0; j < multiplier; j++) {
        ret = buffer_converter_pull(converter, page, page_size);
        assert(ret == 0);
        for (int i = 0; i < page_size; i++) {
          if (page[i] != generated[page_size * j + i]) {
            debug_printf("block %d/%d page %d offset %d mismatch: %02X %02X\n",
              k, repeats, j, i, page[i], generated[page_size * j + i]);
            assert(0);
          }
        }
      }
      ret = buffer_converter_pull(converter, page, page_size);
      assert(ret == 1);
    }
  }
  else { // small blocks (multiple blocks per page)
    int multiplier = page_size / block_size;
    for (int k = 0; k < repeats; k++) {
      random_sequence(generated, page_size);
      for (int j = 0; j < multiplier; j++) {
        for (int i = 0; i < block_size; i++) {
          block[i] = generated[block_size * j + i];
        }
        ret = buffer_converter_push(converter, block, block_size);
        assert(ret == 0);
      }
      ret = buffer_converter_pull(converter, page, page_size);
      assert(ret == 0);
      for (int i = 0; i < page_size; i++) {
        if (page[i] != generated[i]) {
          debug_printf("page %d/%d offset %d mismatch: %02X %02X\n",
            k, repeats, i, page[i], generated[i]);
          assert(0);
        }
      }
      ret = buffer_converter_pull(converter, page, page_size);
      assert(ret == 1);
    }
  }
}

void test_empty_push_and_pull(struct buffer_converter &converter)
{
  char buf[1];
  int ret;

  ret = buffer_converter_push(converter, buf, 0);
  assert(ret == 0);

  ret = buffer_converter_pull(converter, buf, 0);
  assert(ret == 0);
}

int main(void)
{
  int bases[] = {16, 32, 64};
  int multipliers[] = {1, 2, 4, 8};
  int repeats = 4;

  struct buffer_converter converter;
  buffer_converter_reset(converter);

  test_empty_push_and_pull(converter);

  // exercise a number of page size and block size combinations
  //
  // some with small blocks (multiple blocks per page, the typical scenario),
  // some with large blocks (multiple pages per block)
  //
  // do several rounds with each combination, and include runs that add a
  // 'tail' to the input stream, a sequence shorter than a whole page
  //
  for (int i = 0; i < sizeof(bases) / sizeof(int); i++) {
    for (int j = 0; j < sizeof(multipliers) / sizeof(int); j++) {
      for (int k = 1; k <= repeats; k++) {
        int block_size = bases[i];
        int page_size = bases[i] * multipliers[j];
        test_whole_blocks(converter, block_size, page_size, k);
        test_partial_block(converter, block_size, page_size, 1);
        test_partial_block(converter, block_size, page_size, page_size - 1);
        if (multipliers[j] > 1) {
          int block_size = bases[i] * multipliers[j];
          int page_size = bases[i];
          test_whole_blocks(converter, block_size, page_size, k);
          test_partial_block(converter, block_size, page_size, 1);
          test_partial_block(converter, block_size, page_size, block_size - 1);
        }
      }
    }
  }

  printstr("PASS\n");
  return 0;
}
