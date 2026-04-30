# Copyright 2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import re
import subprocess
from pathlib import Path
import time

DEVICE_I2C_ADDRESS = 0x2c

# Helper function to run DFU commands with retries, to improve test robustness against transient I2C errors. This is a workaround.
def run_dfu_with_retry(remote_pi, args, hide=True, retries=3):
    for attempt in range(retries):
        result = remote_pi.run_dfu(args, hide=hide)
        if result.return_code == 0:
            return result
        print(f"run_dfu attempt {attempt + 1}/{retries} failed: {result.stdout} {result.stderr}")
    raise Exception(f"run_dfu failed after {retries} attempts: {args}")


def get_bcd_version(remote_pi, device_i2c_address):
    result = run_dfu_with_retry(remote_pi, f"--i2c-address {device_i2c_address} detach_and_bus_reset")
    match = re.search(r"bcdDevice\s+(0x[0-9a-fA-F]+)", result.stdout)
    if not match:
        raise Exception(f"Could not find bcdDevice in output: {result.stdout}")
    return int(match.group(1), 16)


def test_dfu_rpi(remote_pi, settings):
    """Test that the DFU app on the Raspberry Pi can perform an upgrade and revert to factory successfully
    and that the BCD version reported by the device is correct after each operation"""

    example_path = Path(__file__).parent.parent.parent / "examples/i2c/device/"
    factory_bin = example_path / "bin/factory/i2c_factory.xe"
    update_bin = example_path / "bin/update/i2c_update.xe"

    # Prepare upgrade binary. Step 1 - make DFUable binary from xe file and place in this dir
    print("Preparing upgrade binary...")
    raw_upgrade_output_file = Path(__file__).parent / "i2c_update.bin"
    cmd = f"xflash --no-reporting --factory-version 15.3 --upgrade 1 {str(update_bin)} -o {str(raw_upgrade_output_file)}"
    subprocess.run(cmd, shell=True, check=True)

    # Prepare upgrade binary. Step 2 - transfer file and run suffix generator remotely
    remote_pi.send_file(raw_upgrade_output_file)
    remote_raw_upgrade_file = Path(remote_pi.REMOTE_DIR) / raw_upgrade_output_file.name
    suffixed_upgrade_file = Path(remote_pi.REMOTE_DIR) / "i2c_update_with_suffix.bin"
    args = f"0x20b1 0x1234 {str(remote_raw_upgrade_file)} {str(suffixed_upgrade_file)}"
    remote_pi.run_suffix_generator(args)

    # Flash factory image
    print("Flashing factory image...")
    adapter_id = settings.get("adapter_id")
    cmd = f"xflash --force --adapter-id {adapter_id} --target-file ../../examples/i2c/device/src/xk-voice-l71.xn --erase-all"
    subprocess.run(cmd, shell=True, check=True)
    cmd = f"xflash --force --adapter-id {adapter_id} --factory {factory_bin}"
    subprocess.run(cmd, shell=True, check=True)

    time.sleep(2)  # Wait for device to reboot after factory flash

    # Check BCD version is correct before upgrade
    bcd_version = get_bcd_version(remote_pi, DEVICE_I2C_ADDRESS)
    expected_bcd_version = 0x0101
    assert bcd_version == expected_bcd_version, f"Expected factory version {expected_bcd_version:#06x}, got {bcd_version:#06x}"
    print(f"BCD version check OK: {hex(bcd_version)}")

    # DFU upgrade using RPi
    print("Performing DFU upgrade...")
    args = f"--i2c-address {DEVICE_I2C_ADDRESS} write_upgrade {str(suffixed_upgrade_file)}"
    run_dfu_with_retry(remote_pi, args)

    # Check BCD version is correct after upgrade
    bcd_version = get_bcd_version(remote_pi, DEVICE_I2C_ADDRESS)
    expected_bcd_version = 0x0200
    assert bcd_version == expected_bcd_version, f"Expected factory version {expected_bcd_version:#06x}, got {bcd_version:#06x}"
    print(f"BCD version check OK: {hex(bcd_version)}")

    # Revert to factory image
    print("Reverting to factory image...")
    args = f"--i2c-address {DEVICE_I2C_ADDRESS} revert_factory"
    run_dfu_with_retry(remote_pi, args)

    # Check BCD version is correct after revert
    bcd_version = get_bcd_version(remote_pi, DEVICE_I2C_ADDRESS)
    expected_bcd_version = 0x0101
    assert bcd_version == expected_bcd_version, f"Expected factory version {expected_bcd_version:#06x}, got {bcd_version:#06x}"
    print(f"BCD version check OK: {hex(bcd_version)}")

    print("PASS")
    