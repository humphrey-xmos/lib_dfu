// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_USB_SERVER_H
#define DFU_USB_SERVER_H

#include <xccompat.h>

#include "dfu_interface.h"

/** DFU USB server function
 * 
 * This links the USB device to the DFU library, allowing the device to receive DFU commands over USB.
 * Call this function from the application's `Endpoint0` task.
 * 
 * \param i The usb interface to use for connection to the transport.
 */
#if defined(__XC__)
[[distributable]]
void dfu_usb_server(server interface i_dfu i);
#else
void dfu_usb_server(SERVER_INTERFACE(i_dfu, i));
#endif

#endif // DFU_USB_SERVER_H
