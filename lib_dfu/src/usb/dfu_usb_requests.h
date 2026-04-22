// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_USB_REQUESTS_H
#define DFU_USB_REQUESTS_H

#include <xccompat.h>

#include "dfu.h"
#if defined(DFU_USB_EN) && DFU_USB_EN

#include "xud_device.h"
#include "dfu_interface.h"

/** Check if DFU mode is active
 * Returns 1 if DFU mode is active, 0 if DFU mode is not active.
 */
int dfu_is_mode_active(void);

/** Set DFU mode as active */
void dfu_set_mode_active(void);

/** Set DFU mode as inactive */
void dfu_set_mode_inactive(void);

/** Check the initial state of DFU mode
 * Used during boot to determine whether to enter DFU mode or not.
 * 
 * \retval 0 if DFU mode should not be active (normal boot)
 * \retval 1 if DFU mode should be active (boot to DFU)
 */
int dfu_check_init_state(void);

/** Force DFU mode to be active
 * 
 * Used during boot to force the device into DFU mode.
 * 
 * \note Call only after the DFU thread is running, as otherwise it might hang the system.
 */
void dfu_force_dfu_mode_active(CLIENT_INTERFACE(i_dfu, i));

/** Handle USB reset events
 * 
 * Returns 1 if the device should be in DFU mode, 0 if it should be in application mode.
 */
int dfu_process_reset_state(CLIENT_INTERFACE(i_dfu, i));

/* Helper function for C */
void DFUDelay(unsigned d);

/* Handle XMOS specific DFU requests
 * 
 * Returns XUD_RES_OKAY if request was handled, XUD_RES_ERR if request was not recognised/handled.
 */
int dfu_usb_vendor_requests(XUD_ep ep0_out, XUD_ep ep0_in, REFERENCE_PARAM(USB_SetupPacket_t, sp), CLIENT_INTERFACE(i_dfu, dfuInterface), unsigned int xua_dfu_interface_num);

/* Handle standard DFU requests
 *
 * Returns XUD_RES_OKAY if request was handled, XUD_RES_ERR if request was not recognised/handled.
 */
int dfu_usb_class_int_requests(XUD_ep ep0_out, XUD_ep ep0_in, REFERENCE_PARAM(USB_SetupPacket_t, sp), CLIENT_INTERFACE(i_dfu, dfuInterface));

/* Handle standard SET_CONFIG request
 *
 * Informs DFU layer of USB device configured state.
 */
void dfu_usb_set_configured_state(void);

/* Handle standard SET_CONFIG(0) request
 *
 * Informs DFU layer of USB device configured state.
 */
void dfu_usb_clear_configured_state(void);

#endif /* DFU_USB_EN */
#endif /* DFU_USB_REQUESTS_H */
