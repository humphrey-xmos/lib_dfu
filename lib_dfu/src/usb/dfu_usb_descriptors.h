// Copyright 2011-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DFU_USB_DESCRIPTORS_H
#define DFU_USB_DESCRIPTORS_H

#include <xccompat.h>

// #include "xua.h"
#include "xud_device.h"
#include "dfu.h"
#include "dfu_types.h"

#ifndef __XC__

#ifndef DFU_VENDOR_ID
#error DFU_VENDOR_ID not defined!
#endif

#ifndef DFU_PID
#error DFU_PID not defined!
#endif

#ifndef DFU_PRODUCT_STR_INDEX
#error DFU_PRODUCT_STR_INDEX not defined!!
#endif

#ifndef DFU_MANUFACTURER_STR_INDEX
#error DFU_MANUFACTURER_STR_INDEX not defined!!
#endif

#ifndef DFU_SERIAL_NUMBER_STR_INDEX
#define DFU_SERIAL_NUMBER_STR_INDEX 0
#endif

USB_Descriptor_Device_t DFUdevDesc =
{
    .bLength                        = sizeof(USB_Descriptor_Device_t),
    .bDescriptorType                = USB_DESCTYPE_DEVICE,
#if _XUA_ENABLE_BOS_DESC
    .bcdUSB                         = 0x0201,
#else
    .bcdUSB                         = 0x0200,
#endif
    .bDeviceClass                   = 0, /* See interface */
    .bDeviceSubClass                = 0, /* See interface */
    .bDeviceProtocol                = 0, /* See interface */
    .bMaxPacketSize0                = DFU_TRANSFER_SIZE_BYTES,
    .idVendor                       = DFU_VENDOR_ID,
    .idProduct                      = DFU_PID,
    .bcdDevice                      = DFU_BCD_DEVICE,
    .iManufacturer                  = DFU_MANUFACTURER_STR_INDEX,
    .iProduct                       = DFU_PRODUCT_STR_INDEX,
    .iSerialNumber                  = DFU_SERIAL_NUMBER_STR_INDEX,
    .bNumConfigurations             = 0x01
};

typedef struct
{
    unsigned char bLength;
    unsigned char bDescriptorType;
    unsigned char bmAttributes;
    unsigned short wDetachTimeOut;
    unsigned short wTransferSize;
    unsigned short bcdDFUVersion;
}__attribute__((packed)) USB_DFU_Functional_Descriptor_t;

typedef struct
{
    USB_Descriptor_Configuration_Header_t       Config; /* Configuration header */
    USB_Descriptor_Interface_t                  InterfaceDesc;
    USB_DFU_Functional_Descriptor_t             FunctionalDesc;
}__attribute__((packed)) USB_Config_Descriptor_DFU_t;


USB_Config_Descriptor_DFU_t DFUcfgDesc = {
    .Config =
    {
        .bLength                    = sizeof(USB_Descriptor_Configuration_Header_t),
        .bDescriptorType            = USB_DESCTYPE_CONFIGURATION,
        .wTotalLength               = sizeof(USB_Config_Descriptor_DFU_t),
        .bNumInterfaces             = 1,
        .bConfigurationValue        = 0x01,
        .iConfiguration             = 0x00,
#if (XUA_POWERMODE == XUA_POWERMODE_SELF)
        .bmAttributes               = 192,
#else
        .bmAttributes               = 128,
#endif
        .bMaxPower                  = XUA_BMAX_POWER,
    },
    .InterfaceDesc =
    {
        .bLength                       = sizeof(USB_Descriptor_Interface_t),
        .bDescriptorType               = USB_DESCTYPE_INTERFACE,
        .bInterfaceNumber              = 0,
        .bAlternateSetting             = 0x00,                     /* Must be 0 */
        .bNumEndpoints                 = 0x00,
        .bInterfaceClass               = 0xFE,
        .bInterfaceSubClass            = 0x01,
        .bInterfaceProtocol            = 0x02,
#if (XUA_DFU_EN == 1)
        .iInterface                    = offsetof(StringDescTable_t, dfuStr)/sizeof(char *), /* 8 iInterface */
#else
        .iInterface                    = 0,
#endif
    },
    .FunctionalDesc = {
        .bLength = sizeof(USB_DFU_Functional_Descriptor_t),
        .bDescriptorType = 0x21, //  DFU FUNCTIONAL
        .bmAttributes = DFU_FUNC_ATTRS,
        .wDetachTimeOut = 250,
        .wTransferSize = DFU_TRANSFER_SIZE_BYTES,
        .bcdDFUVersion = 0x0110
    }
};

#endif /* !__XC__ */

#endif /* DFU_USB_DESCRIPTORS_H */
