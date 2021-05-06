# Copyright 2019-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import subprocess, os

def test_crc_algorithm():
    home = os.path.dirname(os.path.abspath(__file__))
    try:
        cmd = [os.path.join(home, os.path.join('bin', 'crc_algorithm'))]
        output = subprocess.check_call(cmd)
    except subprocess.CalledProcessError as e:
        msg = '''Error! Test failed
               \ncmd: %s
               \noutput: %s
               \nreturn_code: %d'''\
               % (' '.join(e.cmd), e.output, e.returncode)
        raise Exception(msg)

if __name__ == "__main__":
    print('test_crc_algorithm')
    test_crc_algorithm()
