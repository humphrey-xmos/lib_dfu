# Copyright 2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pytest
import os
import pathlib
import subprocess
import re
import time

factory_device = "0x0101"
upgrade_device = "0x0200"
overwrite_device = "0x0300"
runtime_mode = "0x01"
dfu_mode = "0x02"

def parse_descriptor(output):
    group_values = []
    descriptor_pattern = r"[a-zA-Z\s]+: bcdDevice (?P<value>[0-9A-Fx]+), [a-zA-Z]+ (?P<attributes>[0-9A-Fx]+), [a-zA-Z]+ (?P<mode>[0-9A-Fx]+) [(](?P<modename>[a-zA-Z]+)[)]"
    for line in output.splitlines():
        result = re.finditer(descriptor_pattern, line)
        for match in result:
            group_values.append(match.group("value", "attributes", "mode", "modename"))

    return group_values


def detach_and_check(app, expected):
    proc = subprocess.run(f"{app} detach_and_bus_reset".split(), text=True, capture_output=True)
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr)
    assert proc.returncode == 0, "Host DFU app failed comms"

    group_values = parse_descriptor(proc.stdout)
    # print(group_values)
    assert len(group_values) > 0

    (value, attributes, mode, modename) = group_values[0]
    if len(group_values) == 2:
        if runtime_mode in mode:
            print(f"Device started in runtime mode {mode}")

        (value, attributes, mode, modename) = group_values[1]
        if dfu_mode in mode:
            print("Device transition to DFU mode")
    else:
        if dfu_mode in mode:
            print("Device already in DFU mode")

    assert expected in value, f"Unexpected device value, expected {expected}, but got {value}"


def revert_factory_and_check(host_app, expected):
    proc = subprocess.run(f"{host_app} revert_factory".split(), text=True, capture_output=True)
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr)
    assert proc.returncode == 0

    detach_and_check(host_app, expected)

'''
This is a manual test that can be run on the Raspberry Pi.
It requires the dfu_i2c host app, and the suffix generator to be built and available in the expected locations.
It also requires the i2c_update.bin test file to be present.
'''
def test_rpi():
    # Check for dfu_utility
    host_file_path =  pathlib.Path(__file__).parent / "../../host/dfu_i2c/bin/dfu_i2c"
    assert host_file_path.exists(), f"Host file path {host_file_path} does not exist"

    # Check that the test file exists
    suffix_file_path = pathlib.Path(__file__).parent / "../../host/suffix_generator/bin/dfu_suffix_generator"
    assert suffix_file_path.exists(), f"Test file {suffix_file_path} does not exist."

    # Check that the test file exists
    test_update_file = pathlib.Path(__file__).parent / "i2c_update.bin"
    assert test_update_file.exists(), f"Test file {test_update_file} does not exist."
    # test_overwrite_file = pathlib.Path(__file__).parent / "i2c_overwrite.bin"
    # assert test_overwrite_file.exists(), f"Test file {test_overwrite_file} does not exist."

    # Check that the test file is not empty
    assert test_update_file.stat().st_size > 0, f"Test file {test_update_file} is empty."

    print(f"Found host app {host_file_path}.")
    print(f"Found suffix app {suffix_file_path}.")
    print(f"Found test file {test_update_file}.")

    target_dfu_file = "i2c_update.dfu"
    target_overwrite_dfu_file = "i2c_overwrite.dfu"

    subprocess.check_call(f"{suffix_file_path} 0x20b1 0x1234 {test_update_file} {target_dfu_file}".split(), text=True)
    # subprocess.check_call(f"{suffix_file_path} 0x20b1 0x1234 {test_overwrite_file} {target_overwrite_dfu_file}".split(), text=True)

    # Clear device is needed, as we don't have "xflash --erase-all ..." available
    revert_factory_and_check(host_file_path, factory_device)

    # Test - detach
    detach_and_check(host_file_path, factory_device)

    # Test - run upgrade, detech and check (value == upgrade_device)
    proc = subprocess.run(f"{host_file_path} write_upgrade {target_dfu_file}".split(), text=True, capture_output=True)
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr)
    assert proc.returncode == 0

    detach_and_check(host_file_path, upgrade_device)

    # Test - run upload, check (file == i2c_update.bin)
    upload_bin_file = "upload.bin"
    proc = subprocess.run(f"{host_file_path} upload {upload_bin_file}".split(), text=True, capture_output=True)
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr)
    assert proc.returncode == 0

    uploaded = pathlib.Path(upload_bin_file)
    assert uploaded.exists()
    compare_length = uploaded.stat().st_size
    assert compare_length > 20000 and compare_length < 60000, "Unexpected length of uploaded file"
    proc = subprocess.run(f"cmp -b -n {compare_length} {upload_bin_file} {test_update_file}".split(), text=True, capture_output=True)
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr)
    assert proc.returncode == 0

    # Test - run download overwriting image, (value == overwrite_device)
    # proc = subprocess.run(f"{host_file_path} write_upgrade {target_overwrite_dfu_file}".split(), text=True, capture_output=True)
    # if proc.returncode != 0:
    #     print(proc.stdout)
    #     print(proc.stderr)
    # assert proc.returncode == 0

    # detach_and_check(host_file_path, overwrite_device)

    # # Test
    revert_factory_and_check(host_file_path, factory_device)
