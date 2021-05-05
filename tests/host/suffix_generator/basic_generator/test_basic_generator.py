# Copyright 2020-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import subprocess, os
import filecmp
import pathlib

HOME = str(pathlib.Path(__file__).resolve().parent)

def test_basic_generator():
    os.chdir(HOME)
    cmd = ['bin/dfu_suffix_generator',
           '0x20B1', '0x0014', '0x0102', 'input.bin', 'output.bin' ]
    try:
        output = subprocess.check_output(cmd)
    except subprocess.CalledProcessError as e:
        msg = '''Error! Test failed
                \ncmd: %s
                \nreturn_code: %d'''\
                % (' '.join(e.cmd), e.returncode)
        raise Exception(msg)
    if not filecmp.cmp(os.path.join(HOME, 'output.bin'),
                       os.path.join(HOME, 'golden.bin')):
        raise Exception('''Error! Test failed
              \ncommand line: %s'''\
              % ' '.join(cmd))
    print('PASS')

if __name__ == "__main__":
    print('test_basic_generator')
    test_basic_generator()
