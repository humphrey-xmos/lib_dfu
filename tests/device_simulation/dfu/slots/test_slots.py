# Copyright 2020-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import subprocess, os

def test_slots():
    home = os.path.dirname(os.path.abspath(__file__))
    boot_address = 4096
    data_address = 8192
    for (partition, expected) in [(1, boot_address), (2, data_address)]:
        try:
            cmd = ['xsim', '--args', os.path.join(home, 'bin', 'slots.xe'),
                   str(boot_address), str(data_address),
                   '0x%x' % partition, str(expected)]
            output = subprocess.check_call(cmd)
        except subprocess.CalledProcessError as e:
            msg = '''Error! Simulator failed
                   \ncmd: %s
                   \noutput: %s
                   \nreturn_code: %d'''\
                   % (str(e.cmd), e.output, e.returncode)
            raise Exception(msg)

if __name__ == "__main__":
    print('test_slots')
    test_slots()
