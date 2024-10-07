#!/usr/bin/env bash

set -euo pipefail

mkdir -p mnt/

just build glove80

sudo echo "need root for next steps"
echo "Put right half of glove80 in flash mode (boot while holding RGUI+I)"

until [ -e /dev/disk/by-label/GLV80RHBOOT ]; do
  sleep 1
  echo -n "."
done

echo "flashing..."

sudo mount /dev/disk/by-label/GLV80RHBOOT mnt
sudo cp firmware/glove80_rh.uf2 mnt/
sudo umount mnt

echo "Put left half of glove80 in flash mode (boot while holding LGUI+E)"

until [ -e /dev/disk/by-label/GLV80LHBOOT ]; do
  sleep 1
  echo -n "."
done

echo "flashing..."

sudo mount /dev/disk/by-label/GLV80LHBOOT mnt
sudo cp firmware/glove80_lh.uf2 mnt/
sudo umount mnt
