// Copyright 2012-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "dfu_flash.h"

#include <platform.h>
#include <xclib.h>
#include <xs1.h>

#include "dfu.h"
#if defined (DFU_ENABLE) && (DFU_ENABLE != 0)

#if (DFU_QUAD_SPI_FLASH)
#include <quadflashlib.h>
#else
#include <flashlib.h>
#endif

#define settw(a, b) \
  { __asm__ __volatile__("settw res[%0], %1" : : "r"(a), "r"(b)); }
#define setc(a, b) \
  { __asm__ __volatile__("setc res[%0], %1" : : "r"(a), "r"(b)); }
#define setclk(a, b) \
  { __asm__ __volatile__("setclk res[%0], %1" : : "r"(a), "r"(b)); }
#define portin(a, b) \
  { __asm__ __volatile__("in %0, res[%1]" : "=r"(b) : "r"(a)); }
#define portout(a, b) \
  { __asm__ __volatile__("out res[%0], %1" : : "r"(a), "r"(b)); }

#ifdef DFU_USER_FLASH_DEVICE

#if (DFU_QUAD_SPI_FLASH)
/* Using specified flash device rather than all supported in tools */
fl_QuadDeviceSpec flash_devices[] = {DFU_USER_FLASH_DEVICE};
#else
/* Using specified flash device rather than all supported in tools */
fl_DeviceSpec flash_devices[] = {DFU_USER_FLASH_DEVICE};
#endif

#endif

#if (DFU_QUAD_SPI_FLASH)
static fl_QSPIPorts p_qflash = {PORT_SQI_CS, PORT_SQI_SCLK, PORT_SQI_SIO, CLKBLK_DFU_FLASHLIB};
#else
static fl_PortHolderStruct p_flash = {XS1_PORT_1A, PORT_SPI_SS, PORT_SPI_CLK, XS1_PORT_1D, CLKBLK_DFU_FLASHLIB};
#endif

void DFUCustomFlashEnable() __attribute__((weak));
void DFUCustomFlashEnable() {}

void DFUCustomFlashDisable() __attribute__((weak));
void DFUCustomFlashDisable() {}

enum flash_status flash_enable_ports() __attribute__((weak));
enum flash_status flash_enable_ports() {
  int result = 0;
#if (DFU_QUAD_SPI_FLASH)
  /* Ports not shared */
  
#ifdef DFU_USER_FLASH_DEVICE
  result = fl_connectToDevice(&p_qflash, flash_devices, sizeof(flash_devices) / sizeof(fl_QuadDeviceSpec));
#else
  /* Use default flash list */
  result = fl_connect(&p_qflash);
#endif

#else
  setc(p_flash.spiMISO, XS1_SETC_INUSE_OFF);
  setc(p_flash.spiCLK, XS1_SETC_INUSE_OFF);
  setc(p_flash.spiMOSI, XS1_SETC_INUSE_OFF);
  setc(p_flash.spiSS, XS1_SETC_INUSE_OFF);
  setc(p_flash.spiClkblk, XS1_SETC_INUSE_OFF);

  setc(p_flash.spiMISO, XS1_SETC_INUSE_ON);
  setc(p_flash.spiCLK, XS1_SETC_INUSE_ON);
  setc(p_flash.spiMOSI, XS1_SETC_INUSE_ON);
  setc(p_flash.spiSS, XS1_SETC_INUSE_ON);
  setc(p_flash.spiClkblk, XS1_SETC_INUSE_ON);
  // Seems to be duplicate of above, is this needed or accidental?
  setc(p_flash.spiClkblk, XS1_SETC_INUSE_ON);

  setclk(p_flash.spiMISO, XS1_CLKBLK_REF);
  setclk(p_flash.spiCLK, XS1_CLKBLK_REF);
  setclk(p_flash.spiMOSI, XS1_CLKBLK_REF);
  setclk(p_flash.spiSS, XS1_CLKBLK_REF);

  setc(p_flash.spiMISO, XS1_SETC_BUF_BUFFERS);
  setc(p_flash.spiMOSI, XS1_SETC_BUF_BUFFERS);

  settw(p_flash.spiMISO, 8);
  settw(p_flash.spiMOSI, 8);

#ifdef DFU_USER_FLASH_DEVICE
  result = fl_connectToDevice(&p_flash, flash_devices, sizeof(flash_devices) / sizeof(fl_DeviceSpec));
#else
  /* Use default flash list */
  result = fl_connect(&p_flash);
#endif
#endif // DFU_QUAD_SPI_FLASH

  if (!result) {
    /* All okay.. */
    return DFU_FLASH_OK;
  } else {
    return DFU_FLASH_OPEN_ERROR;
  }
}

enum flash_status flash_disable_ports() __attribute__((weak));
enum flash_status flash_disable_ports() {
  fl_disconnect();

#if (!DFU_QUAD_SPI_FLASH)
  setc(p_flash.spiMISO, XS1_SETC_INUSE_OFF);
  setc(p_flash.spiCLK, XS1_SETC_INUSE_OFF);
  setc(p_flash.spiMOSI, XS1_SETC_INUSE_OFF);
  setc(p_flash.spiSS, XS1_SETC_INUSE_OFF);
#endif

  return DFU_FLASH_OK;
}

#else /* DFU_ENABLE not defined or 0 */

void DFUCustomFlashEnable() __attribute__((weak));
void DFUCustomFlashEnable() {}

void DFUCustomFlashDisable() __attribute__((weak));
void DFUCustomFlashDisable() {}

enum flash_status flash_enable_ports() __attribute__((weak));
enum flash_status flash_enable_ports() {
  return DFU_FLASH_OK;
}

enum flash_status flash_disable_ports() __attribute__((weak));
enum flash_status flash_disable_ports() {
  return DFU_FLASH_OK;
}

#endif /* DFU_ENABLE */
