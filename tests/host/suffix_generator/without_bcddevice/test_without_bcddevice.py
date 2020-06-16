# Copyright (c) 2020, XMOS Ltd, All rights reserved
import subprocess, os
import filecmp
import pathlib

HOME = str(pathlib.Path(__file__).resolve().parent)

def test_without_bcddevice():
    os.chdir(HOME)
    cmd = ['bin/dfu_suffix_generator',
           '0x20B1', '0x0014', 'input.bin', 'output.bin' ]
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
    print('test_without_bcddevice')
    test_without_bcddevice()
