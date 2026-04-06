#!/bin/bash
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
CONTAINER_IMAGE="localhost/cf-base:latest_linux_arm64"
RSYNC_URL="rsync://dl.fedoraproject.org/fedora-alt/iot/43/IoT/aarch64/images/"
EXPANDED_SIZE="7G"
INPUT_DIR="/input"
OUTPUT="/output/Clockworkpi-Fedora-Base-raw-43.raw"

WORKING_IMAGE="working.raw"

# ── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

# ── Preflight ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]]           && die "Must be run as root"
[[ ! -d "$INPUT_DIR" ]]     && die "Input directory $INPUT_DIR not found"
[[ ! -f "$INPUT_DIR/efi/config.txt" ]] && die "Missing $INPUT_DIR/efi/config.txt"
[[ ! -d "$INPUT_DIR/efi/overlays" ]]   && die "Missing $INPUT_DIR/efi/overlays/"
[[ ! -d "/output" ]]        && die "Output directory /output not found"

dnf install -y rsync xz e2fsprogs util-linux parted

# ── Cleanup ──────────────────────────────────────────────────────────────────
LOOP_DEV=""

cleanup() {
  log "Cleaning up..."
  umount /target/boot/efi /target/boot /target  || true
  [[ -n "$LOOP_DEV" ]] && losetup -d "$LOOP_DEV" && log "Detached $LOOP_DEV"
  # rm -f "$WORKING_IMAGE"
}
trap cleanup EXIT

mkdir -p /tmp/build
cd /tmp/build

# ── Download ─────────────────────────────────────────────────────────────────

if ls $INPUT_DIR/*.raw  1> /dev/null 2>&1; then
  RAW=$(ls $INPUT_DIR/*.raw | head -n1 | xargs -n1 basename)  

  log "Using $RAW..." 
  cp $INPUT_DIR/$RAW "$WORKING_IMAGE"

elif ls $INPUT_DIR/*.raw.xz 1> /dev/null 2>&1; then
  RAW=$(ls $INPUT_DIR/*.raw.xz | head -n1 | xargs -n1 basename)  

  log "Using $RAW..." 
  cp $INPUT_DIR/$RAW .

  log "Decompressing $RAW..."
  unxz --stdout "$RAW" > "$WORKING_IMAGE"
else
  log "Fetching image listing..."
  RAW=$(rsync --list-only "$RSYNC_URL" \
    | awk '{print $5}' \
    | grep 'Fedora-IoT-raw-.*\.raw\.xz$' \
    | sort -V | tail -n1)
  [[ -z "$RAW" ]] && die "No IoT image found at $RSYNC_URL"

  log "Latest listing is $RAW."

  log "Downloading $RAW..."
  rsync -P "$RSYNC_URL$RAW" .

  log "Decompressing $RAW..."
  unxz --stdout "$RAW" > "$WORKING_IMAGE"

fi

# ── Prepare image ─────────────────────────────────────────────────────────────
log "Expanding image file to $EXPANDED_SIZE..."
truncate -s "$EXPANDED_SIZE" "$WORKING_IMAGE"

log "Attaching loop device..."
LOOP_DEV=$(losetup -fP --show "$WORKING_IMAGE")
udevadm settle
partprobe $LOOP_DEV
log "Attached to $LOOP_DEV"

log "Expanding root partition..."
parted -s "$LOOP_DEV" resizepart 3 100%
partprobe "$LOOP_DEV"
udevadm settle

P_ESP="${LOOP_DEV}p1"
P_BOOT="${LOOP_DEV}p2"
P_ROOT="${LOOP_DEV}p3"

log "Getting confirmation to continue..."
echo "  ESP: $P_ESP"
echo "  BOOT: $P_BOOT"
echo "  ROOT: $P_ROOT"
read -r -p "Type 'y' to continue: " confirm
[[ "$confirm" != "y" ]] && die "Aborted by user"

# ── Format and mount ──────────────────────────────────────────────────────────
log "Formatting boot and root partitions..."
mkfs.ext4 -F "$P_BOOT"
mkfs.ext4 -F "$P_ROOT"

log "Mounting partitions..."
mkdir -p /target
mount "$P_ROOT" "/target"
mkdir -p /target/boot
mount "$P_BOOT" "/target/boot"
mkdir -p /target/boot/efi
mount "$P_ESP" "/target/boot/efi"

# ── Inject bootloader files ──────────────────────────────────────────────────────────
log "Injecting bootloader files..."
/bin/cp -rf "$INPUT_DIR/efi/" /target/boot

# ── Install ───────────────────────────────────────────────────────────────────
log "Installing $CONTAINER_IMAGE to image..."
bootc install to-filesystem /target \
  --source-imgref "containers-storage:$CONTAINER_IMAGE" \
  --skip-finalize --skip-fetch-check --generic-image

bash || true

# ── Output ───────────────────────────────────────────────────────
cp "$WORKING_IMAGE" "$OUTPUT"

log "Done: $OUTPUT"
