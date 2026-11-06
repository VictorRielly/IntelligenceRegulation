#!/bin/bash
# Make an Ubuntu 24.04 LTS installer USB stick on macOS, for the zk60 RTX 5090 desktop.
# Guide: docs/zkmatrix-poc/ZK60_RTX5090_BRINGUP.md
#
#   scripts/rtx5090/make_ubuntu_usb_macos.sh --list          # show external disks (nothing is written)
#   scripts/rtx5090/make_ubuntu_usb_macos.sh --check diskN   # the safety checks only (nothing is written)
#   scripts/rtx5090/make_ubuntu_usb_macos.sh diskN           # download + verify the ISO, then ERASE diskN and write it
#
# What it does:
#   1. Finds the newest Ubuntu 24.04.x desktop amd64 image on releases.ubuntu.com (from its SHA256SUMS), downloads it to
#      ~/Downloads (or reuses a copy already there), and checks its SHA-256. If gpg is installed it also checks the
#      SHA256SUMS signature against Ubuntu's CD image signing key.
#   2. Refuses any disk that is internal, not a whole disk, not USB, not removable/ejectable, or smaller than the image.
#   3. Asks you to type the disk name again, then unmounts it, writes the image with dd and ejects it.
# ALL DATA ON THE CHOSEN USB STICK IS ERASED.
set -euo pipefail

RELEASE_URL="https://releases.ubuntu.com/24.04"
DL_DIR="${HOME}/Downloads"
# Ubuntu CD Image Automatic Signing Key (2012) <cdimage@ubuntu.com>
UBUNTU_CD_KEY_FPR="843938DF228D22F7B3742BC0D94AA3F0EFE21092"

die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo "==> $*"; }

[ "$(uname -s)" = "Darwin" ] || die "this script is for macOS (use the guide's Linux/Windows notes elsewhere)"

plist_get() { # plist_get <disk> <key>
  diskutil info -plist "/dev/$1" 2>/dev/null | plutil -extract "$2" raw -o - - 2>/dev/null || echo "?"
}

list_disks() {
  say "External physical disks (pick your USB stick by its size and name):"
  diskutil list external physical || true
}

check_disk() { # check_disk <diskN> <min_bytes>
  local d="$1" min="${2:-0}"
  [[ "$d" =~ ^disk[0-9]+$ ]] || die "give a whole-disk name like disk4 (not $d, not a partition like disk4s1)"
  diskutil info "/dev/$d" > /dev/null 2>&1 || die "/dev/$d does not exist"
  local whole internal proto removable ejectable size name
  whole=$(plist_get "$d" WholeDisk)
  internal=$(plist_get "$d" Internal)
  proto=$(plist_get "$d" BusProtocol)
  removable=$(plist_get "$d" RemovableMedia)
  ejectable=$(plist_get "$d" Ejectable)
  size=$(plist_get "$d" Size)
  name=$(plist_get "$d" MediaName)
  echo "    /dev/$d: \"$name\", $((size / 1000000000)) GB, protocol $proto, internal=$internal, removable=$removable, ejectable=$ejectable, whole disk=$whole"
  [ "$whole" = "true" ] || die "/dev/$d is not a whole disk"
  [ "$internal" = "false" ] || die "/dev/$d is an INTERNAL disk; refusing"
  [ "$proto" = "USB" ] || die "/dev/$d is not on USB (protocol $proto); refusing"
  if [ "$removable" != "true" ] && [ "$ejectable" != "true" ]; then die "/dev/$d is neither removable nor ejectable; refusing"; fi
  if [ "$min" -gt 0 ] && [ "$size" -lt "$min" ]; then die "/dev/$d ($size bytes) is smaller than the image ($min bytes)"; fi
  if [ "$size" -gt 300000000000 ]; then die "/dev/$d is larger than 300 GB; that looks like a backup drive, not a USB stick. Refusing"; fi
  say "/dev/$d passes the safety checks"
}

fetch_iso() {
  mkdir -p "$DL_DIR"
  local sums="$DL_DIR/ubuntu-24.04-SHA256SUMS"
  say "Fetching $RELEASE_URL/SHA256SUMS"
  curl -fsSL "$RELEASE_URL/SHA256SUMS" -o "$sums"
  ISO=$(grep -oE 'ubuntu-24\.04(\.[0-9]+)*-desktop-amd64\.iso' "$sums" | sort -V | tail -1)
  [ -n "$ISO" ] || die "no 24.04 desktop amd64 image listed in SHA256SUMS"
  WANT=$(awk -v f="$ISO" '{n = $2; sub(/^\*/, "", n); if (n == f) print $1}' "$sums")
  [[ "$WANT" =~ ^[0-9a-f]{64}$ ]] || die "could not read the SHA-256 of $ISO from SHA256SUMS"
  say "Newest image: $ISO (sha256 $WANT)"
  if command -v gpg > /dev/null 2>&1; then
    curl -fsSL "$RELEASE_URL/SHA256SUMS.gpg" -o "$sums.gpg"
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$UBUNTU_CD_KEY_FPR" > /dev/null 2>&1 || true
    if gpg --batch --status-fd 1 --verify "$sums.gpg" "$sums" 2> /dev/null | grep -q "VALIDSIG $UBUNTU_CD_KEY_FPR"; then
      say "SHA256SUMS signature valid (Ubuntu CD image key $UBUNTU_CD_KEY_FPR)"
    else
      die "SHA256SUMS signature did NOT verify against $UBUNTU_CD_KEY_FPR"
    fi
  else
    say "gpg not installed: skipping the signature check (the SHA-256 check below still runs over HTTPS-fetched sums)"
  fi
  ISO_PATH="$DL_DIR/$ISO"
  if [ ! -f "$ISO_PATH" ]; then
    say "Downloading $ISO (about 6 GB) to $DL_DIR"
    curl -fL --retry 3 -C - "$RELEASE_URL/$ISO" -o "$ISO_PATH.part"
    mv "$ISO_PATH.part" "$ISO_PATH"
  else
    say "Reusing $ISO_PATH"
  fi
  say "Checking the image's SHA-256 (a minute or two)"
  local got
  got=$(shasum -a 256 "$ISO_PATH" | awk '{print $1}')
  [ "$got" = "$WANT" ] || die "SHA-256 mismatch for $ISO_PATH: got $got, want $WANT. Delete it and run again"
  say "Image verified"
}

case "${1:-}" in
  "" | -h | --help)
    sed -n 2,16p "$0"; exit 0 ;;
  --list)
    list_disks; exit 0 ;;
  --check)
    [ -n "${2:-}" ] || die "usage: $0 --check diskN"
    check_disk "$2" 0; exit 0 ;;
esac

DISK="$1"
check_disk "$DISK" 0
fetch_iso
ISO_BYTES=$(stat -f %z "$ISO_PATH")
check_disk "$DISK" "$ISO_BYTES"
echo
echo "About to ERASE /dev/$DISK and write $ISO to it. Everything on that stick will be lost."
read -r -p "Type the disk name ($DISK) to continue: " again
[ "$again" = "$DISK" ] || die "names differ; nothing was written"
say "Unmounting /dev/$DISK"
diskutil unmountDisk "/dev/$DISK"
say "Writing (sudo asks for your Mac password; press Ctrl+T in this window to see progress; about 5-15 minutes)"
sudo dd if="$ISO_PATH" of="/dev/r$DISK" bs=4m
sync
say "Ejecting /dev/$DISK"
diskutil eject "/dev/$DISK" || true
say "Done. The stick is an Ubuntu 24.04 installer. Next: the guide's 'On the desktop' section."
