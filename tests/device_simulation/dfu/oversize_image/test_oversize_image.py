# Copyright 2020-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import subprocess, os

def test_oversize_image():
    home = os.path.dirname(os.path.abspath(__file__))
    for partitions in [1, 2, 3]:
        try:
            cmd = ['axe', '--args', os.path.join(home, 'bin', 'oversize_image.xe'),
                   str(partitions)]
            subprocess.check_call(cmd)
        except subprocess.CalledProcessError as e:
            msg = '''Error! Simulator failed
                   \ncmd: %s
                   \noutput: %s
                   \nreturn_code: %d'''\
                   % (str(e.cmd), e.output, e.returncode)
            raise Exception(msg)

if __name__ == "__main__":
    print('test_oversize_image')
    test_oversize_image()
