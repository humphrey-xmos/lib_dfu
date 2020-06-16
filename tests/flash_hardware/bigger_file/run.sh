#!/bin/sh
echo bigger_file

# expected 1060864 = 1MB data partition base + 4KB for sector-padded hardware build section + 4KB for sector-padded serial number section + 4KB for sector-padded data factory image

data_partition_generator --hardware-build 0x12345678 --spi-spec-bin spispec.bin --regular-sector-size 4096 --factory factory.json -o /tmp/data.bin || exit $?
xflash --no-compression --noinq --quad-spi-clock=12.5MHz --boot-partition-size 1048576 --factory ../hello_world.xe --data /tmp/data.bin || exit $?
xrun --io --args bin/bigger_file.xe 1060864
