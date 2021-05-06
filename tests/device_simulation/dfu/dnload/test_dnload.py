# Copyright 2019-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import subprocess, os

def test_dnload():
    home = os.path.dirname(os.path.abspath(__file__))
    test_instances = [
        (32, 1, 0), (32, 1, 1), (32, 3, 0), (32, 8, 0), (32, 9, 0), (32, 9, 31),
        (32, 128, 0), (32, 512, 0), (128, 1, 0), (128, 1, 1), (128, 1, 127),
        (128, 2, 0), (128, 8, 0), (128, 9, 0), (128, 128, 0), (256, 1, 0),
        (256, 2, 0), (256, 8, 0), (256, 16, 0), (256, 17, 0),
        (256, 64, 0), (512, 1, 0), (512, 7, 0), (512, 8, 0), (512, 9, 0),
        (512, 32, 0), (512, 32, 1), (512, 32, 256), (512, 32, 511)
    ]
    for repeats in [1, 2, 4]:
        for partitions in [1, 2, 3]:
            for (block_size, block_count, tail_size) in test_instances:
                try:
                    cmd = ['axe', '--args', os.path.join(home, 'bin', 'dnload.xe'),
                           str(block_size), str(block_count), str(tail_size),
                           str(repeats), str(partitions)]
                    subprocess.check_call(cmd)
                except subprocess.CalledProcessError as e:
                    msg = '''Error! Simulator failed
                           \ncmd: %s
                           \noutput: %s
                           \nreturn_code: %d'''\
                           % (str(e.cmd), e.output, e.returncode)
                    raise Exception(msg)

if __name__ == "__main__":
    print('test_dnload')
    test_dnload()
