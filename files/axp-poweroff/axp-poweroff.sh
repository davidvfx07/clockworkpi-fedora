#!/bin/bash
set -e

# Sync filesystems again to ensure data safety before power cut, just in case
sync

modprobe i2c-dev || true

# Ensure AXP20x driver is not locking the i2c driver
echo '0-0034' > /sys/bus/i2c/drivers/axp20x-i2c/unbind 2>/dev/null || true

sleep 0.5

/usr/bin/i2cset -y 0 0x34 0x32 0xcb
