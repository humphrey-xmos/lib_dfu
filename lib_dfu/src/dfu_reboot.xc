// Copyright 2011-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <platform.h>
#include <print.h>
#include <xs1_su.h>

#include "dfu.h"
#include "xs2_su_registers.h"
#include "xud_hal.h"

#define PLL_MASK 0x3FFFFFFF

#if (DFU_ENABLE == 1)

/* Note, this function is prototyped in xs1.h only from 13 tools onwards */
unsigned get_tile_id(tileref);

extern tileref tile[];

/* Function to reset the given tile */
static void reset_tile(unsigned const tileId)
{
    unsigned int pllVal;

    read_sswitch_reg(tileId, 6, pllVal);
    pllVal &= PLL_MASK;
    write_sswitch_reg_no_ack(tileId, 6, pllVal);
}

/* Reboots XMOS device by writing to the PLL config register
 * Note - resetting is per *node* not tile
 */
void device_reboot(void)
{
    unsigned int localTileId = get_local_tile_id();
    unsigned int tileId;
    unsigned int tileArrayLength;
    unsigned int localTileNum;

    XUD_HAL_EnterMode_TristateDrivers();

    tileArrayLength = sizeof(tile)/sizeof(tileref);

    /* Note - we could be in trouble if this doesn't return 0/1 since
     * this code doesn't properly handle any network topology other than a
     * simple line
     */
    /* Find tile index of the local tile ID */
    for(unsigned int tileNum = 0;  tileNum < tileArrayLength; tileNum++)
    {
        if (get_tile_id(tile[tileNum]) == localTileId)
        {
            localTileNum = tileNum;
            break;
        }
    }

    /* Reset all even tiles, starting from the remote ones */
    for(int tileNum = tileArrayLength-2;  tileNum>=0; tileNum-=2)
    {
        /* Cannot cast tileref to unsigned! */
        tileId = get_tile_id(tile[tileNum]);

        /* Do not reboot local tile (or tiles residing on the same node) yet */
        if((localTileNum | 1) != (tileNum | 1))
        {
            reset_tile(tileId);
        }
    }

    /* Finally reboot the node this tile resides on */
    reset_tile(localTileId);

    while (1);
}

#else

// Testing only - not a real reboot.
void device_reboot(void)
{
}

#endif
