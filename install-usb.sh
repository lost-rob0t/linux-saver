#!/usr/bin/env bash
# Write the linux-saver ISO to a USB stick.
#
#   sudo ./install-usb.sh [--dd] /dev/sdX [data-source-dir]
#
# default: GPT disk with p1 = FAT32 ESP holding the ISO contents (UEFI boot)
#          and p2 = ext4 SAVER_DATA carrying opencode config, the arch-expert
#          user KB, ssh authorized_keys and artifacts (persists across boots).
# --dd:    raw whole-disk dd of the ISO (UEFI+BIOS boot, no persistence).
#
# [data-source-dir] overrides what seeds the data partition (default: your
# ~/.config/opencode plus this repo's sibling arch-expert/kb).
set -euo pipefail

MODE=persistent
case "${1:-}" in
    --dd) MODE=dd; shift ;;
esac

DISK="${1:-}"
SRC="${2:-}"
[ -b "$DISK" ] || { echo "usage: $0 [--dd] /dev/sdX [data-source-dir]" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

REPO=$(cd "$(dirname "$0")" && pwd)
ISO=$(find "$REPO/out" -name '*.iso' 2>/dev/null | head -1)
[ -n "$ISO" ] || { echo "error: run ./build.sh first (no out/*.iso)" >&2; exit 1; }

for c in parted mkfs.vfat mkfs.ext4 rsync; do
    command -v "$c" >/dev/null || { echo "error: missing command: $c" >&2; exit 1; }
done

MODEL=$(lsblk -dno MODEL "$DISK" | head -1)
SIZE=$(lsblk -dno SIZE "$DISK" | head -1)
echo "target: $DISK ($MODEL, $SIZE)"
echo "iso:    $ISO"

# Refuse the running system's disk.
ROOT_DEV=$(findmnt -n -o SOURCE /)
ROOT_DISK=/dev/$(lsblk -no PKNAME "$ROOT_DEV" | head -1)
if [ "$DISK" = "$ROOT_DISK" ]; then
    echo "refusing to wipe the disk the running system boots from" >&2
    exit 1
fi
if lsblk -nr "$DISK" | grep -qE ' (boot|swap|/$)'; then
    echo "refusing: a partition on $DISK looks mounted/active" >&2
    exit 1
fi

echo "WARNING: this destroys everything on $DISK."
read -r -p "type WIPE to continue: " ACK
[ "$ACK" = "WIPE" ] || { echo "aborted"; exit 1; }

partition_of() {
    case "$1" in
        *[0-9]) echo "$1p$2" ;;
        *) echo "$1$2" ;;
    esac
}

WORK=$(mktemp -d)
P1=$(partition_of "$DISK" 1)
P2=$(partition_of "$DISK" 2)
cleanup() {
    umount "$WORK/iso" "$WORK/boot" "$WORK/data" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

if [ "$MODE" = "dd" ]; then
    dd if="$ISO" of="$DISK" bs=4M conv=fsync status=progress
    sync
    echo "done: raw ISO written to $DISK (no data partition)"
    exit 0
fi

wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt
ISO_MB=$(( $(stat -c%s "$ISO") / 1024 / 1024 + 512 ))
parted -s "$DISK" mkpart SAVER fat32 1MiB "${ISO_MB}MiB"
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart SAVER_DATA ext4 "${ISO_MB}MiB" 100%
partprobe "$DISK"
udevadm settle 2>/dev/null || true

mkfs.vfat -n SAVER "$P1"
mkfs.ext4 -q -L SAVER_DATA "$P2"

mkdir -p "$WORK/iso" "$WORK/boot" "$WORK/data"
mount -o loop,ro "$ISO" "$WORK/iso"
mount "$P1" "$WORK/boot"
mount "$P2" "$WORK/data"

# FAT has no symlinks: dereference (-L). Includes EFI/, boot/ and the
# squashfs-backed /nix tree the live system scans for at boot.
rsync -rL --exclude lost+found "$WORK/iso/" "$WORK/boot/"

# Seed the persistent data partition.
mkdir -p "$WORK/data"/{config/opencode,arch-expert/kb,ssh,artifacts}
if [ -n "$SRC" ] && [ -d "$SRC" ]; then
    rsync -a "$SRC/" "$WORK/data/"
else
    [ -d "$HOME/.config/opencode" ] && rsync -a "$HOME/.config/opencode/" "$WORK/data/config/opencode/"
    [ -d "$REPO/../arch-expert/kb" ] && rsync -a "$REPO/../arch-expert/kb/" "$WORK/data/arch-expert/kb/"
fi

{
    echo "iso=$(basename "$ISO")"
    echo "written=$(date -Is)"
    echo "host=$(uname -a)"
} > "$WORK/data/saver-version.txt"

sync
echo "done: $DISK"
echo "  p1 $P1  FAT32 SAVER       (boot; label must stay SAVER)"
echo "  p2 $P2  ext4 SAVER_DATA   (opencode config, arch-expert kb, ssh keys, artifacts)"
echo "put your ssh pubkey at /data/ssh/authorized_keys on the stick to unlock headless login."
