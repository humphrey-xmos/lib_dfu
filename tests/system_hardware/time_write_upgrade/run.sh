#!/bin/sh
# use 10ms as timeout for any library function calls
# longest expected is the sector-erased test that for data partition has been seen to take 6ms
python make_test_json.py /tmp/factory.json 2.0.1 262144
python make_test_json.py /tmp/upgrade.json 2.0.2 262144
data_partition_generator --regular-sector-size 4096 --hardware-build 0x12345678 --spi-spec-bin spispec.bin -o /tmp/factory.bin --factory /tmp/factory.json || exit $?
data_partition_generator --regular-sector-size 4096 -o /tmp/upgrade.bin --upgrade 0x202 /tmp/upgrade.json || exit $?
xflash --no-compression --noinq --quad-spi-clock=12.5MHz --boot-partition-size 1048576 --factory ../hello_world.xe --data /tmp/factory.bin || exit $?
xrun --io --args bin/time_write_upgrade.xe ../hello_world.bin /tmp/upgrade.bin 1000000 || exit $?
