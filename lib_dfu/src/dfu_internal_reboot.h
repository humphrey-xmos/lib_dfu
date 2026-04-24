// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_INTERNAL_REBOOT_H
#define DFU_INTERNAL_REBOOT_H

#include <stdint.h>

/* Helper function for C */
void dfu_delay_raw(unsigned d);

/* Reboot the device */
void device_internal_reboot(void);


#endif /* DFU_INTERNAL_REBOOT_H */
