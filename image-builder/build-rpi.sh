#!/bin/bash
set -euo pipefail

# CONTAINER_IMAGE="localhost/cf-base:latest_linux_arm64"
# OUTPUT_IMAGE="/output/Clockworkpi-Fedora-base-raw-43.raw"
# IMAGE_SIZE="7GB"

INPUT_DIR="/input"
OUTPUT_DIR="/output"

# Values taken from official IOT raw image
ESP_START_MB=17
ESP_END_MB=525
BOOT_END_MB=2700

WORKING_IMAGE="working.raw"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -ne 0 ]]           && die "Must be run as root"
[[ ! -d "$INPUT_DIR" ]]     && die "Input directory $INPUT_DIR not found"
[[ ! -f "$INPUT_DIR/efi/config.txt" ]] && die "Missing $INPUT_DIR/efi/config.txt"
[[ ! -d "$INPUT_DIR/efi/overlays" ]]   && die "Missing $INPUT_DIR/efi/overlays/"
[[ ! -d "/output" ]]        && die "Output directory /output not found"

log "Building $OUTPUT_IMAGE using $CONTAINER_IMAGE with size $IMAGE_SIZE..."

log "Installing dependencies..."
dnf install -y e2fsprogs util-linux parted dosfstools \
  bcm283x-firmware uboot-images-armv8

LOOP_DEV=""

cleanup() {
  log "Cleaning up..."
  umount /target/boot/efi /target/boot /target 2>/dev/null || true
  [[ -n "$LOOP_DEV" ]] && losetup -d "$LOOP_DEV" && log "Detached $LOOP_DEV"
}
trap cleanup EXIT


mkdir -p /tmp/build
cd /tmp/build


log "Creating raw image..."
truncate -s "$IMAGE_SIZE" "$WORKING_IMAGE"

log "Partitioning..."
parted -s "$WORKING_IMAGE" \
  mklabel msdos \
  mkpart primary fat16 "${ESP_START_MB}MiB" "${ESP_END_MB}MiB" \
  set 1 boot on \
  mkpart primary ext4 "${ESP_END_MB}MiB" "${BOOT_END_MB}MiB" \
  mkpart primary ext4 "${BOOT_END_MB}MiB" 100%

log "Attaching loop device..."
LOOP_DEV=$(losetup -fP --show "$WORKING_IMAGE")
udevadm settle
partprobe $LOOP_DEV
log "Attached to $LOOP_DEV."

P_ESP="${LOOP_DEV}p1"
P_BOOT="${LOOP_DEV}p2"
P_ROOT="${LOOP_DEV}p3"

log "Please ensure the following contains only loop devices."
log "Getting confirmation to continue..."
echo "  ESP: $P_ESP"
echo "  BOOT: $P_BOOT"
echo "  ROOT: $P_ROOT"
read -r -p "Type 'y' to continue: " confirm
[[ "$confirm" != "y" ]] && die "Aborted."

log "Formatting partitions..."
mkfs.vfat -F 16 "$P_ESP"
mkfs.ext4 -F "$P_BOOT"
mkfs.ext4 -F "$P_ROOT"

log "Mounting partitions..."
mkdir -p /target
mount "$P_ROOT" "/target"
mkdir -p /target/boot
mount "$P_BOOT" "/target/boot"
mkdir -p /target/boot/efi
mount "$P_ESP" "/target/boot/efi"

log "Injecting bootloader..."
/bin/cp -rf "/boot/efi/" /target/boot
/bin/cp -f "/usr/share/uboot/rpi_arm64/u-boot.bin" /target/boot/efi/rpi-u-boot.bin
/bin/cp -rf "$INPUT_DIR/efi/" /target/boot

log "Installing $CONTAINER_IMAGE to image..."
bootc install to-filesystem /target \
  --source-imgref "$CONTAINER_IMAGE" \
  --skip-finalize --skip-fetch-check --generic-image

log "Copying to $OUTPUT_DIR..."
cp "$WORKING_IMAGE" "$OUTPUT_DIR/$OUTPUT_IMAGE"

log "Finished building $OUTPUT_IMAGE."
