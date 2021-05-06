// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef __dfu_buffer_converter_h__
#define __dfu_buffer_converter_h__

#include <xccompat.h>

#define BUFFER_CONVERTER_QUEUE_SIZE_BYTES 512
#define BUFFER_CONVERTER_PADDING_BYTE 0x00

/**
 * Buffer converter state
 *
 * The converter is a small FIFO with variable input and output element size
 *
 * The name buffer converter represents its typical use for converting
 * DFU blocks to flash pages. Flash page is normally 256 bytes. Some USB DFU
 * implementations use DFU blocks of 32 bytes, so smaller than flash page.
 * Others might use as much as 512 bytes, and it is useful to use the same
 * routines for converting from one size to another.
 *
 * In addition to push and pull operations, there is a padded pull. This is
 * a pull of any amount of data up to the given size, padded with zeroes.
 * Typically this will be used to remove a partial page that may have
 * accumulated as a result of partial blocks.
 */
struct buffer_converter {
  int wp; /**< Write pointer */
  int rp; /**< Read pointer */
  int fullness;
  int capacity;
  char storage[BUFFER_CONVERTER_QUEUE_SIZE_BYTES];
};

/**
 * Prepare an empty buffer converter
 *
 * \param obj                  State structure
 *
 * Note that input/output sizes aren't specified, they are supplied with each
 * push/pull operation (so variable)
 */
void buffer_converter_reset(REFERENCE_PARAM(struct buffer_converter, obj));

/**
 * Push a block
 *
 * \param obj                  Initialised buffer converter
 * \param data                 Block to push in
 * \param data_size_bytes      Block size in bytes
 *
 * \return                     Zero for success, non-zero for overflow
 */
int buffer_converter_push(REFERENCE_PARAM(struct buffer_converter, obj),
                          const char data[], int data_size_bytes);

/**
 * Pull a page
 *
 * \param obj                  Initialised buffer converter
 * \param data                 Destination to put page in
 * \param data_size_bytes      Page size in bytes
 *
 * \return                     Zero for success, non-zero for underflow
 */
int buffer_converter_pull(REFERENCE_PARAM(struct buffer_converter, obj),
                          char data[], int data_size_bytes);

/**
 * Pull a page, allowing underflow - pad remaining bytes with a constant value
 *
 * \param obj                  Initialised buffer converter
 * \param data                 Destination to put page in
 * \param data_size_bytes      Page size in bytes
 *
 * \return                     Valid bytes read, so excluding any padding
 */
int buffer_converter_padded_pull(REFERENCE_PARAM(struct buffer_converter, obj),
                                 char data[], int data_size_max_bytes);

#endif
