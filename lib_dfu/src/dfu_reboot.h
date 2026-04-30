// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_REBOOT_H
#define DFU_REBOOT_H

#include "dfu.h"

/** Reboot the device
 * 
 * This function reboots the device by writing to the PLL config register.
 * This will call dfu_user_pre_reboot() before rebooting, which allows the user to
 * perform any necessary cleanup or preparation before the device reboots.
 * 
 * \param delay_ms The delay in milliseconds before the reboot occurs.
 */
void dfu_reboot(int32_t delay_ms);

/** Function to notify user's application that a reboot is about to occur.
 * 
 * This is called from dfu_reboot() before the device is rebooted, and can be used to perform any necessary cleanup or preparation before the reboot occurs.
 * 
 * The default weak implementation does nothing, but the user can override this function with their own implementation if desired.
 */
void dfu_user_pre_reboot(void);


#endif /* DFU_REBOOT_H */
