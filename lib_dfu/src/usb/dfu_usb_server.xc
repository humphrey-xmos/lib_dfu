// Copyright 2011-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include "dfu.h"
#if defined(DFU_USB_EN) && (DFU_USB_EN == 1)
#include "dfu_usb_server.h"

#include <xs1.h>
#include <platform.h>
#include <string.h>

#include "dfu_types.h"
#include "dfu_interface.h"
#include "dfu_reboot.h"

[[distributable]]
void dfu_usb_server(server interface i_dfu i)
{
    while(1)
    {
        select
        {
            case i.handle_dfu_request(struct dfu_request_params request, unsigned data_buffer[], unsigned data_buffer_length)
                -> struct dfu_cmd_response dfu:

                unsigned char data_local[DFU_TRANSFER_SIZE_BYTES];

                /* Split reads and writes */
                if ((request.request == DFU_UPLOAD) || (request.request == DFU_GETSTATUS) || (request.request == DFU_GETSTATE))
                {
                    dfu = dfu_request_with_arguments(request.request, data_local, request.length, null);
                    /* Worst-case buffer copy */
                    memcpy(data_buffer, data_local, DFU_TRANSFER_SIZE_BYTES);
                }
                else if (request.request == XMOS_DFU_GETPROFILE)
                {
                    // TODO
                    dfu.status = DFU_API_BAD_PARAM;
                    dfu.return_data_len = 0;
                    dfu.deferred_request = 0;
                }
                else
                {
                    if (data_buffer_length > DFU_TRANSFER_SIZE_BYTES) {
                        dfu.status = DFU_API_BAD_PARAM;
                        dfu.return_data_len = 0;
                        dfu.deferred_request = 0;
                    }
                    else
                    {
                        int32_t request_value = (int32_t)request.value;
                        memcpy(data_local, data_buffer, data_buffer_length);
                        dfu = dfu_request_with_arguments(request.request, data_local, data_buffer_length, request_value);
                    }
                }

  	            if ((dfu.deferred_request == DFU_DEFERRED_ACTION_REBOOT_TO_DFU) || (dfu.deferred_request == DFU_DEFERRED_ACTION_REBOOT))
                {
                    /* This is USB DFU mode entry mechanism, delegate to USB request handling. */
                }
                else if (dfu.deferred_request != 0)
                {
                    dfu_request_with_arguments(dfu.deferred_request, null, 0, null);
                    dfu.deferred_request = 0;
                }
                break;

            case i.finish():
                return;
        }
    }
}

#endif /* DFU_USB_EN */
