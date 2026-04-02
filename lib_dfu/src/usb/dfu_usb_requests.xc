// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "dfu_usb_requests.h"

#include "dfu.h"
#if defined(DFU_USB_EN) && DFU_USB_EN

#include <timer.h>
#include <xs1.h>
#include <xassert.h>
#include <xccompat.h>

#include "dfu_reboot.h"
#include "xud_device.h"
#include "dfu_types.h"

#if defined(__XS2A__)
/* Note range 0x7FFC8 - 0x7FFFF guaranteed to be untouched by tools */
#define FLAG_ADDRESS 0x7ffcc
#elif defined(__XS3A__)
/* Note range 0xFFFC8 - 0xFFFFF guaranteed to be untouched by tools */
#define FLAG_ADDRESS 0xfffcc
#else
#error DFU code requires __XS2A__ or __XS3A__ to be defined
#endif

#define _BOOT_DFU_MODE_FLAG (0x11042011)

/* Store Flag to fixed address */
static void SetDFUFlag(unsigned x)
{
    asm volatile("stw %0, %1[0]" :: "r"(x), "r"(FLAG_ADDRESS));
}

/* Load flag from fixed address */
static unsigned GetDFUFlag()
{
    unsigned x;
    asm volatile("ldw %0, %1[0]" : "=r"(x) : "r"(FLAG_ADDRESS));
    return x;
}

#define USB_BMREQ_H2D_VENDOR_INT    ((USB_BM_REQTYPE_DIRECTION_H2D << 7) | \
                                    (USB_BM_REQTYPE_TYPE_VENDOR << 5) | \
                                    (USB_BM_REQTYPE_RECIP_INTER))

/* Windows core USB/device driver stack may not like device coming off bus for
 * a very short period of less than 500ms. Enforce at least 500ms by stalling.
 * This may not have the desired effect depending on whether 'off the bus'
 * requires device terminations disabled (PHY off). In that case we would be
 * better off doing the reboot to DFU and then delaying PHY initialisation
 * instead. Suggest revisiting.
 */
#define DELAY_BEFORE_REBOOT_TO_DFU_MS     500

static int DFU_mode_active = 0;

int DFUModeIsActive(void)
{
    return DFU_mode_active;
}

void DFUSetModeActive()
{
    DFU_mode_active = 1;
}

void DFUSetModeInactive()
{
    DFU_mode_active = 0;
}

void DFUDelay(unsigned d)
{
    timer tmr;
    unsigned s;
    tmr :> s;
    tmr when timerafter(s + d) :> void;
}

int32_t DFUCheckInitState()
{
    // Setting the flag, below, has always resulted in a reboot.
    unsigned flag = GetDFUFlag();

//#define START_IN_DFU 1
#ifdef START_IN_DFU
    flag = _BOOT_DFU_MODE_FLAG;
#endif

    int32_t ret = 0;
    if (flag == _BOOT_DFU_MODE_FLAG)
    {
        ret = 1;
        DFUSetModeActive();
    } else {
        DFUSetModeInactive();
    }
    return ret;
}

// Tell the DFU state machine that a USB reset has occurred
/* USB bus reset
 * Input: USB bus reset event.
 * Output: 1 if in DFU mode, 0 if not in DFU mode
 * State handling: On USB bus reset signalling
 * - APP_IDLE on boot with "valid" firmware (only ever valid).
 * - DFU_IDLE after request to reset from application to DFU mode (DFU_DETACH).
 * 
 * Note: DFU mode -> DFU_ERROR on boot with "invalid" firmware not possible with flashed factory firmware.
 */
int DFUProcessResetState(client interface i_dfu i)
{
    unsigned int inDFU = 0;

    unsigned flag;
    flag = GetDFUFlag();

//#define START_IN_DFU 1
#ifdef START_IN_DFU
    flag = _BOOT_DFU_MODE_FLAG;
#endif

    if (flag == _BOOT_DFU_MODE_FLAG)
    {
        /*
         * Effectively in STATE_APP_DETACH state on entry here.
         * To get here the device has rebooted with the flag set.
         */
        inDFU = 1;
        // TODO - flag is sticky at the moment to ride through multiple resets from the host (Windows).
        // Consider clearing flag on detection of enumeration.
    }

    struct dfu_request_params request = { XMOS_DFU_BUS_RESET, 0, 0, 0 };
    request.value = inDFU;
    /* Interface used here such that the handler can be on another tile */
    unsigned data_buffer[1];
    struct dfu_cmd_response result = i.HandleDfuRequest(request, data_buffer, 0);
    
    // Return code of 0 means normal operation (APP_IDLE), non-zero means we are in DFU mode (DFU_IDLE or DFU_ERROR).
    if (result.status)
    {
        // In DFU mode...
        if (!DFUModeIsActive())
        {
            DFUSetModeActive();
        }
    }
    else
    {
        if (DFUModeIsActive())
        {
            DFUSetModeInactive();
        }
    }
    // TODO , can we move this up...
    if (result.deferred_request == DFU_DEFERRED_ACTION_REBOOT)
    {
        DFUDelay(DELAY_BEFORE_REBOOT_FROM_DFU_MS * XS1_TIMER_KHZ);
        device_reboot();
    }

    return inDFU;
}

static int DFUDeviceRequests(XUD_ep ep0_out, XUD_ep &?ep0_in, USB_SetupPacket_t &sp, unsigned int altInterface, client interface i_dfu i)
{
    (void)altInterface;

    unsigned int data_buffer_len = 0;
    unsigned int data_buffer[(DFU_TRANSFER_SIZE_BYTES / 4) + 1];

    if(sp.bmRequestType.Direction == USB_BM_REQTYPE_DIRECTION_H2D)
    {
        // Host to device
        if (sp.wLength)
            XUD_GetBuffer(ep0_out, (data_buffer, unsigned char[]), data_buffer_len);
    }
    /* Swap to dfu_request_params to avoid having USB SP struct as dependency of DFU. */
    struct dfu_request_params request;
    request.request = sp.bRequest;
    request.value = sp.wValue;
    request.index = sp.wIndex;
    request.length = sp.wLength;
    /* Interface used here such that the handler can be on another tile */
    struct dfu_cmd_response result = i.HandleDfuRequest(request, data_buffer, data_buffer_len);

    if (result.deferred_request == DFU_DEFERRED_ACTION_REBOOT_TO_DFU) {
        SetDFUFlag(_BOOT_DFU_MODE_FLAG);
    } else {
        // Yes, we do need to clear this at every opportunity.
        // The flag should only be set when we are requesting a reset to DFU mode.
        SetDFUFlag(0);
    }

    int returnVal = 0;
    /* Check if the request was handled */
    if(result.status == DFU_API_SUCCESS)
    {
        if ((sp.bmRequestType.Direction == USB_BM_REQTYPE_DIRECTION_D2H) && (sp.wLength != 0))
        {
            returnVal = XUD_DoGetRequest(ep0_out, ep0_in, (data_buffer, unsigned char[]), result.return_data_len, result.return_data_len);
        }
        else
        {
            returnVal = XUD_DoSetRequestStatus(ep0_in);
        }

  	    // If device reset requested, handle after command acknowledgement
  	    if (result.deferred_request == DFU_DEFERRED_ACTION_REBOOT_TO_DFU)
  	    {
            DFUDelay(DELAY_BEFORE_REBOOT_TO_DFU_MS * XS1_TIMER_KHZ);
            device_reboot();
        }
        else if (result.deferred_request == DFU_DEFERRED_ACTION_REBOOT)
        {
            DFUDelay(DELAY_BEFORE_REBOOT_FROM_DFU_MS * XS1_TIMER_KHZ);
            device_reboot();
        }
    } else {
        returnVal = XUD_RES_ERR;
    }
  	return returnVal;
}

int dfu_usb_vendor_requests(XUD_ep ep0_out, XUD_ep ep0_in, USB_SetupPacket_t &sp, client interface i_dfu dfuInterface, unsigned int usb_dfu_interface_num) {
    int result = XUD_RES_ERR;
    // From Thesycon DFU driver v2.66.0 onwards, the XMOS_DFU_REVERTFACTORY request comes as a H2D vendor request and not as a class request addressed to the DFU interface
    unsigned bmRequestType = (sp.bmRequestType.Direction << 7) | (sp.bmRequestType.Type << 5) | (sp.bmRequestType.Recipient);
    if((bmRequestType == USB_BMREQ_H2D_VENDOR_INT) && (sp.bRequest == XMOS_DFU_REVERTFACTORY))
    {
        unsigned interface_num = sp.wIndex & 0xff;
        unsigned dfu_if = (DFU_mode_active) ? 0 : usb_dfu_interface_num;

        if(interface_num == dfu_if)
        {
            result = DFUDeviceRequests(ep0_out, ep0_in, sp, 0, dfuInterface);
        }
    }
    return result;
}

int dfu_usb_class_int_requests(XUD_ep ep0_out, XUD_ep ep0_in, USB_SetupPacket_t &sp, client interface i_dfu dfuInterface) {
    return DFUDeviceRequests(ep0_out, ep0_in, sp, 0, dfuInterface);
}

#endif /* DFU_USB_EN */
