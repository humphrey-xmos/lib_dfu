lib_dfu change log
==================

2.0.0
-----

  * ADDED:    Support for XCommon-CMake build system
  * ADDED:    Example I2C DFU device and host for XCORE
  * ADDED:    I2C DFU host app ``dfu_i2c`` for Raspberry Pi
  * ADDED:    DFU types now common with ``lib_xua``
  * CHANGED:  Moved `xmosdfu` application from ``lib_xua``.
  * CHANGED:  Migrated from ``lib_flash_data_partition`` to XMOS tools
    ``quadflash`` library for flash access
  * CHANGED:  Moved file dfu_control_server.xc from ``lib_device_control``.

  * Changes to dependencies:

    - lib_flash_data_partition: Removed dependency

    - lib_logging: 3.0.0 -> 3.4.0

    - lib_xassert: 4.0.0 -> 4.3.2

1.1.0
-----

  * CHANGED: Use XMOS Public Licence Version 1

1.0.6
-----

  * CHANGED: Pin Python package versions
  * REMOVED: not necessary cpanfile

  * Changes to dependencies:

    - lib_flash_data_partition: 2.0.3 -> 2.2.0

1.0.5
-----

  * FIXED: Suffix generator and verifier byte-order portability
  * FIXED: Build suffix generator in release mode to reduce number of
    dynamically linked libraries

1.0.4
-----

  * CHANGED: Include bcdDevice in suffix

1.0.3
-----

  * ADDED: Switch to newly added single-spec flash connect function

  * Changes to dependencies:

    - lib_flash_data_partition: 2.0.0 -> 2.0.3

1.0.2
-----

  * FIXED: Windows compile warnings

1.0.1
-----

  * ADDED: Handling of oversize images (protect factory programming in flash)

1.0.0
-----

  * First release

  * Changes to dependencies:

    - lib_flash_data_partition: 0.0.1 -> 2.0.0

0.0.1
-----

  * Initial version

  * Changes to dependencies:

    - lib_flash_data_partition: Added dependency 0.0.1

    - lib_logging: Added dependency 3.0.0

    - lib_xassert: Added dependency 4.0.0

