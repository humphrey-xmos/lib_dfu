// Copyright (c) 2020, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>

// byte order portability
#ifdef _WIN32
#define htole16(x) (x) // Windows little endian only
#define htole32(x) (x)
#elif __APPLE__
#include <libkern/OSByteOrder.h>
#define htole16(x) OSSwapHostToLittleInt16(x)
#define htole32(x) OSSwapHostToLittleInt32(x)
#else
#include <endian.h>
#endif

#include "dfu_suffix.h"
#include "crc.h"

bool verbose = false;

int main(int argc, char **argv)
{
  unsigned vendor_id = 0, product_id = 0, bcd_device = 0;
  const char *in_file = NULL, *out_file = NULL;

  if (argc == 6 || argc == 5) {
    vendor_id = strtoul(argv[1], NULL, 0);
    product_id = strtoul(argv[2], NULL, 0);
  }
  if (argc == 5) {
    bcd_device = 0xFFFF;
    in_file = argv[3];
    out_file = argv[4];
  }
  if (argc == 6) {
    bcd_device = strtoul(argv[3], NULL, 0);
    in_file = argv[4];
    out_file = argv[5];
  }
  if (vendor_id == 0 || product_id == 0 || bcd_device == 0) {
    fprintf(stderr, "\
usage: dfu_suffix_generator VENDOR_ID PRODUCT_ID [BCD_DEVICE] BIN_FILE_IN DFU_FILE_OUT\n\
\n\
       VENDOR_ID, PRODUCT_ID and BCD_DEVICE are non-zero 16bit values\n\
       decimal or hexadecimal format\n\
       0xFFFF means do not verify this field\n\
       0 is invalid value\n");
    exit(1);
  }

  unsigned crc = crc_init();
  char buf[1024];
  FILE * in_stream = fopen(in_file, "rb");
  FILE * out_stream = fopen(out_file, "wb");
  size_t read = 0;

  if (in_stream == NULL) {
    fprintf(stderr, "error: could not open input file %s\n", in_file);
    exit(1);
  }
  if (out_stream == NULL) {
    fprintf(stderr, "error: could not open output file %s\n", out_file);
    exit(1);
  }

  while ((read = fread(buf, 1, sizeof(buf), in_stream)) != 0) {

    for (int i = 0; i < read; i++) {
      crc_step(&crc, buf[i]);
    }

    if (fwrite(buf, 1, read, out_stream) != read) {
      fprintf(stderr, "error: I/O write and read mismatch\n");
      exit(1);
    }
  }
  fclose(in_stream);

  crc = crc_finish(crc);

  // hard little endian order for serialisation
  struct dfu_suffix suffix = {
    .crc = htole32(crc),
    .suffix_length = sizeof(struct dfu_suffix),
    .signature = DFU_SIGNATURE,
    .bcd_dfu = htole16(DFU_BCD),
    .vendor_id = htole16(vendor_id),
    .product_id = htole16(product_id),
    .bcd_device = htole16(bcd_device)
  };

  char reversed[sizeof(struct dfu_suffix)];
  for (int i = 0; i < sizeof(reversed); i++) {
    reversed[i] = ((char*)&suffix)[sizeof(reversed) - 1 - i];
  }

  if (fwrite(reversed, sizeof(reversed), 1, out_stream) != 1) {
    fprintf(stderr, "error: I/O write of suffix invalid return value\n");
    exit(1);
  }

  return 0;
}
