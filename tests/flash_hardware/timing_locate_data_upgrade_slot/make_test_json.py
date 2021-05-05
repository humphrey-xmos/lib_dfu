# Copyright 2020-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import sys

def make_test_json(file_name, compatibility_version, item_length):
    item = [(n & 255) for n in range(0, item_length)]
    with open(file_name, 'w') as f:
        f.write('{"compatibility_version": "%s",' % compatibility_version)
        f.write('"items": [{"type": 2, "bytes": [\n0x%02x' % item[0])
        for i in range(1, len(item)):
            f.write(',\n0x%02x' % item[i])
        f.write('\n]}]}')

if __name__ == "__main__":
    assert len(sys.argv) == 4
    make_test_json(sys.argv[1], sys.argv[2], int(sys.argv[3]))
