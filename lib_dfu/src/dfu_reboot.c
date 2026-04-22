// Copyright 2011-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <platform.h>
#include <print.h>

#include "dfu.h"
#include "dfu_internal_reboot.h"

#if (DFU_ENABLE == 1)

void dfu_user_pre_reboot(void) __attribute__((weak));
void dfu_user_pre_reboot(void)
{
    /* Default weak implementation does nothing - user can override with their own implementation if desired */
}

/* Reboots XMOS device by writing to the PLL config register
 * Note - resetting is per *node* not tile
 */
void device_reboot(void)
{
    dfu_user_pre_reboot();
    device_internal_reboot();
}

#else

// Testing only - not a real reboot.
void device_reboot(void)
{
}

#endif
