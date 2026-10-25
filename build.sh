#!/usr/bin/env bash
# Build the linux-saver rescue ISO.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v nix >/dev/null; then
    echo "error: nix is required (https://nixos.org)" >&2
    exit 1
fi

mkdir -p out
nix build .#iso -o out/result

ISO=$(find "$(readlink -f out/result)" -name '*.iso' | head -1)
[ -n "$ISO" ] || { echo "error: no ISO in build output" >&2; exit 1; }

echo
echo "ISO:     $ISO"
echo "Size:    $(numfmt --to=iec "$(stat -c%s "$ISO")")"
echo "SHA256:  $(sha256sum "$ISO" | cut -d' ' -f1)"
echo
echo "Write to a USB stick (persistent data partition):"
echo "  sudo ./install-usb.sh /dev/sdX"
echo
echo "Or plain whole-disk dd (no persistence):"
echo "  sudo ./install-usb.sh --dd /dev/sdX"
