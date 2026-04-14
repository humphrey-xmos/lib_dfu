// Copyright 2015-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_INTERFACE_H
#define DFU_INTERFACE_H

#if __XC__

#include <stdint.h>
#include "dfu.h"

struct dfu_request_params
{
    uint16_t request;
    uint16_t value;
    uint16_t index;
    uint16_t length;
};

interface i_dfu
{
    struct dfu_cmd_response HandleDfuRequest(struct dfu_request_params request, unsigned data_buffer[], unsigned data_buffer_length);
    void finish();
};

#endif
#endif


