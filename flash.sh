#!/usr/bin/env bash

set -euo pipefail

mkdir -p mnt/

just build glove80

sudo echo "need root for next steps"
read -n1 -rp "Put right half of glove80 in flash mode and then press any key"
echo ""

sudo mount /dev/disk/by-label/GLV80RHBOOT mnt
sudo cp firmware/glove80_rh.uf2 mnt/
sudo umount mnt

read -n1 -rp "Put left half of glove80 in flash mode and then press any key"
echo ""

sudo mount /dev/disk/by-label/GLV80LHBOOT mnt
sudo cp firmware/glove80_lh.uf2 mnt/
sudo umount mnt
