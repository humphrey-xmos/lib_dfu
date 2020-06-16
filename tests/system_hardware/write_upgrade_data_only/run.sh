#!/bin/sh
# upgrade address 1060864 = 1MB data partition base + 4KB for sector-padded hardware build section + 4KB for sector-padded serial number section + 4KB for sector-padded factory data image
data_partition_generator --regular-sector-size 4096 --hardware-build 0x12345678 --spi-spec-bin spispec.bin -o /tmp/factory.bin --factory factory.json || exit $?
data_partition_generator --regular-sector-size 4096 -o /tmp/upgrade.bin --upgrade 0x202 upgrade.json || exit $?
for block_size in 32 128 256 512 ; do
  xflash --no-compression --noinq --quad-spi-clock=12.5MHz --boot-partition-size 1048576 --factory ../hello_world.xe --data /tmp/factory.bin || exit $?
  xrun --io --args bin/write_upgrade_data_only.xe /tmp/upgrade.bin $block_size 1060864 || exit $?
done
