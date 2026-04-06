#!/bin/bash
set -e

# Sync filesystems to ensure data safety before power cut
sync

modprobe i2c-dev || true

# Ensure AXP20x driver is unbound
echo '0-0034' > /sys/bus/i2c/drivers/axp20x-i2c/unbind 2>/dev/null || true

sleep 0.5

/usr/bin/i2cset -y 0 0x34 0x32 0xcb
