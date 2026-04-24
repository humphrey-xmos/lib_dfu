// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_USB_REQUESTS_H
#define DFU_USB_REQUESTS_H

#include <xccompat.h>

#include "dfu.h"
#if (defined(DFU_USB_EN) && DFU_USB_EN) || defined(__DOXYGEN__)

#include "xud_device.h"
#include "dfu_interface.h"

/* Helper function for C */
void DFUDelay(unsigned d);

/**
 * \defgroup lib_dfu_api_usb USB API
 * \{
 */

/** Check if DFU mode is active
 * 
 * This is used in a variety of places to coordinate the application.
 * Such as; resolving the interface number to respond to, determining which USB descriptors to return,
 * whether to allow certain commands, etc.
 * 
 * \return 1 if DFU mode is active, 0 if DFU mode is not active.
 */
int dfu_is_mode_active(void);

/** Set DFU mode as active. Typically not used in the application. */
void dfu_set_mode_active(void);

/** Set DFU mode as inactive. Typically not used in the application. */
void dfu_set_mode_inactive(void);

/** Check the initial state of DFU mode
 * 
 * Used during boot to determine whether to enter DFU mode or not.
 * 
 * When entering DFU mode during boot, this function returns 1, and the application can then disable or halt other tasks not needed during DFU.
 * 
 * \retval 0 if DFU mode should not be active (normal boot)
 * \retval 1 if DFU mode should be active (boot to DFU)
 */
int dfu_check_init_state(void);

/** Force DFU state machine into dfuIDLE state.
 * 
 * Used during boot to force the device into DFU mode. Typically called after dfu_check_init_state() returns true, to ensure the device enters DFU mode.
 * 
 * \note Call only after the DFU thread is running, as otherwise it might deadlock the system.
 */
void dfu_force_dfu_mode_active(CLIENT_INTERFACE(i_dfu, i));

/** Handle USB reset events
 * 
 * Call from endpoint0 task when `(result == XUD_RES_UPDATE)` and `XUD_BusState_t busState = XUD_GetBusState(...)` returns `(busState == XUD_BUS_RESET)`.
 * 
 * \note This function will call the DFU interface, so should only be called after the DFU thread is running. 
 *       If called before the DFU thread is running, or before the interface is available, it may cause a deadlock.
 * 
 * \return 1 if the device should be in DFU mode, 0 if it should be in application mode.
 */
int dfu_process_reset_state(CLIENT_INTERFACE(i_dfu, i));

/** Handle XMOS specific DFU requests
 * 
 * Call from endpoint0 task.
 * 
 * \return XUD_RES_OKAY if request was handled, XUD_RES_ERR if request was not recognised/handled.
 */
int dfu_usb_vendor_requests(XUD_ep ep0_out, XUD_ep ep0_in, REFERENCE_PARAM(USB_SetupPacket_t, sp), CLIENT_INTERFACE(i_dfu, dfuInterface), unsigned int xua_dfu_interface_num);

/** Handle standard DFU requests
 * 
 * Call from endpoint0 task.
 *
 * \return XUD_RES_OKAY if request was handled, XUD_RES_ERR if request was not recognised/handled.
 */
int dfu_usb_class_int_requests(XUD_ep ep0_out, XUD_ep ep0_in, REFERENCE_PARAM(USB_SetupPacket_t, sp), CLIENT_INTERFACE(i_dfu, dfuInterface));

/** Handle standard SET_CONFIGURATION request
 *
 * Informs DFU layer of USB device configured state.
 */
void dfu_usb_set_configured_state(void);

/** Handle standard SET_CONFIGURATION request
 *
 * Informs DFU layer of USB device configured state.
 */
void dfu_usb_clear_configured_state(void);

/** \} */

#endif /* DFU_USB_EN */
#endif /* DFU_USB_REQUESTS_H */
