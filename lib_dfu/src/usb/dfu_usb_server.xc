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
            case i.HandleDfuRequest(struct dfu_request_params request, unsigned data_buffer[], unsigned data_buffer_length)
                -> struct dfu_cmd_response dfu:

                unsigned char data_local[DFU_TRANSFER_SIZE_BYTES];
                // if (request.length != data_buffer_length)
                // {
                //     dfu.status = DFU_API_DATA_LENGTH_ERROR;
                //     dfu.return_data_len = data_buffer_length;
                //     break;
                // }

                // TODO - do we pass value "inDFU" into state machine to tidy this up?
                // If we are booting into DFU mode...
                if ((request.request == XMOS_DFU_BUS_RESET) && (request.value))
                {
                    /* USB specific DFU mode entry mechanism 
                     * Only send DFU_DETACH and BUS_RESET if request.value is set and we are in APP_IDLE state
                     * Otherwise, ignore */
                    struct dfu_cmd_response getstate_response = dfu_request_with_arguments(DFU_GETSTATE, data_local, DFU_GET_STATE_PAYLOAD_SIZE_BYTES, null);
                    if ((getstate_response.status == DFU_API_SUCCESS) && (data_local[0] == STATE_APP_IDLE))
                    {
                        struct dfu_request_params prepend_detach = { DFU_DETACH, 0, 0, 0 };
                        dfu_request_with_arguments(DFU_DETACH, data_local, 0, null);
                        dfu = dfu_request_with_arguments(request.request, data_local, 0, null);
                    }
                    else
                    {
                        dfu.status = DFU_OK;
                        dfu.return_data_len = 0;
                        dfu.deferred_request = 0;
                    }
                    // TODO fix this in dfu_usb_requests...
                    dfu.status = request.value;
                }
                else
                {
                    /* Split reads and writes */
                    if ((request.request == DFU_UPLOAD) || (request.request == DFU_GETSTATUS) || (request.request == DFU_GETSTATE) || (request.request == XMOS_DFU_GET_DESCRIPTOR))
                    {
                        dfu = dfu_request_with_arguments(request.request, data_local, request.length, null);
                        memcpy(data_buffer, data_local, DFU_TRANSFER_SIZE_BYTES);
                    } else {
                        int32_t blocknum = request.value;
                        memcpy(data_local, data_buffer, data_buffer_length);
                        dfu = dfu_request_with_arguments(request.request, data_local, data_buffer_length, blocknum);
                    }
                }

                // debug_printf("DFU USB command status=%d\n", dfu.status);

  	            if ((dfu.deferred_request == DFU_DEFERRED_ACTION_REBOOT_TO_DFU) || (dfu.deferred_request == DFU_DEFERRED_ACTION_REBOOT)) {
                    /* This is USB DFU mode entry mechanism, delegate to USB request handling. */
                } else if (dfu.deferred_request != 0) {
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
