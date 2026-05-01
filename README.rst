:orphan:

##############################################
lib_dfu: Device Firmware Upgrade (DFU) Library
##############################################

:vendor: XMOS
:version: 2.1.0
:scope: General Use
:description: Device firmware upgrade over a serial interface
:category: General Purpose
:keywords: Utility, USB, Serial interface
:devices: xcore-200, xcore.ai

*******
Summary
*******

The Device Firmware Upgrade (DFU) library provides functionality to
facilitate firmware updates over almost any transport physical layer. It includes
support for handling DFU packets, managing firmware images, and ensuring
the integrity of the update process.

********
Features
********

- One upgrade slot
- Support USB DFU spec v1.1
- Support for custom transport layers

************
Known issues
************

- USB example reports several warnings such as "port "XS1_PORT_1F" on tile[0] is not connected to any pins in this package.",
  this is normal on small packages that do not have all the pins bonded out.
- The ``lib_device_control`` client handling currently consumes an additional thread as it is not distributable.
- For DFU over I2C the bus speed of up to 100kbps is supported. This is also supported with no clock stretching for all commands except ``upload``.
- DFU_ABORT request is supported in upload but not in download.

****************
Development repo
****************

* `lib_dfu <https://www.github.com/xmos/lib_dfu>`_ (https://www.github.com/xmos/lib_dfu)

**************
Required tools
**************

* XMOS XTC Tools: 15.3.1 or later

*********************************
Required libraries (dependencies)
*********************************

* `lib_logging <https://www.xmos.com/libraries/lib_logging>`_ (https://www.xmos.com/libraries/lib_logging)
* `lib_xassert <https://www.xmos.com/libraries/lib_xassert>`_ (https://www.xmos.com/libraries/lib_xassert)

*************************
Related application notes
*************************

* `AN02019 - Device Firmware Upgrade over USB <https://www.xmos.com/application-notes/an02019>`_ (https://www.xmos.com/application-notes/an02019)

*******
Support
*******

This package is supported by XMOS Ltd. Issues can be raised against the software at
`www.xmos.com/support <https://www.xmos.com/support>`_ or using GitHub `issues <https://github.com/xmos/lib_dfu/issues>`_.
