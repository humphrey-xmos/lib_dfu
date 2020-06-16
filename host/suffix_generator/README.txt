DFU Suffix Generator
====================

Typical usage
-------------

Input (image.bin below) is a boot image produced by xflash or a data partition
image produced by the appropriate generator utility (Flash data partition
library). Output (final.bin below) is a version of the same with DFU suffix
appended.

    dfu_suffix_generator 0x20B1 0x0014 0x0102 image.bin final.bin
