// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdio.h>
#include <platform.h>
#include <xs1.h>
#include <print.h>

#include "dfu.h"
#include "dfu_flash.h"

#define TIMEOUT_MS XS1_TIMER_HZ // 1 second

void delay_ms(uint32_t ms)
{
    timer delay;
    unsigned time_now;
    unsigned timeout;
    delay :> time_now;
    timeout = time_now + (ms * XS1_TIMER_KHZ);
    delay when timerafter(timeout) :> void;
}

int main(void)
{
    printstr("Checking for upgrade images...\n");
    int status = flash_init();
    if(status == DFU_FLASH_OK) {
        printstr("Opened flash.\n");
        int32_t sector_size = flash_get_sector_size();
        enum flash_status erase_status;

        do {
            erase_status = flash_erase_sector_async(sector_size);
            /* wait */
            delay_ms(1);
        } while (erase_status == DFU_FLASH_BUSY);

        if (erase_status == DFU_FLASH_OK) {
            printstr("Flash cleared.\n");
        } else {
            printstr("Flash Error.\n");
        }
        flash_deinit();
        printstr("Closed flash.\n");
    }
    return 0;
}
