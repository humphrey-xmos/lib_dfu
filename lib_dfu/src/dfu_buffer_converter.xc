// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include "dfu_buffer_converter.h"

void buffer_converter_reset(struct buffer_converter &obj)
{
  obj.wp = 0;
  obj.rp = 0;
  obj.fullness = 0;
  obj.capacity = BUFFER_CONVERTER_QUEUE_SIZE_BYTES;
}

int buffer_converter_push(struct buffer_converter &obj,
                          const char data[], int data_size_bytes)
{
  if (obj.fullness + data_size_bytes > obj.capacity)
    return 1;

  for (int i = 0; i < data_size_bytes; i++) {
    obj.storage[obj.wp] = data[i];
    obj.wp = (obj.wp + 1) % BUFFER_CONVERTER_QUEUE_SIZE_BYTES;
  }

  obj.fullness += data_size_bytes;
  return 0;
}

int buffer_converter_pull(struct buffer_converter &obj,
                          char data[], int data_size_bytes)
{
  if (obj.fullness < data_size_bytes)
    return 1;

  for (int i = 0; i < data_size_bytes; i++) {
    data[i] = obj.storage[obj.rp];
    obj.rp = (obj.rp + 1) % BUFFER_CONVERTER_QUEUE_SIZE_BYTES;
  }

  obj.fullness -= data_size_bytes;
  return 0;
}

int buffer_converter_padded_pull(REFERENCE_PARAM(struct buffer_converter, obj),
                                 char data[], int data_size_max_bytes)
{
  int bytes_available = obj.fullness < data_size_max_bytes ? obj.fullness :
                                                             data_size_max_bytes;
  for (int i = 0; i < bytes_available; i++) {
    data[i] = obj.storage[obj.rp];
    obj.rp = (obj.rp + 1) % BUFFER_CONVERTER_QUEUE_SIZE_BYTES;
  }
  for (int i = bytes_available; i < data_size_max_bytes; i++) {
    data[i] = BUFFER_CONVERTER_PADDING_BYTE;
  }

  obj.fullness -= bytes_available;
  return bytes_available;
}
