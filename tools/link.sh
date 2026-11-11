#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Link the addon into your game client so edits show up after /reload.
#   tools/link.sh "/path/to/World of Warcraft/<forever folder>/Interface/AddOns"
# The Forever client's folder name varies by install; pass your own AddOns path.
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: tools/link.sh <path to Interface/AddOns>" >&2
    exit 1
fi

source_dir="$(cd "$(dirname "$0")/.." && pwd)/PerennialUI"
target="$1/PerennialUI"

if [ ! -d "$1" ]; then
    echo "AddOns folder not found: $1" >&2
    exit 1
fi
if [ -e "$target" ]; then
    echo "$target already exists. Remove it first if you want to relink." >&2
    exit 1
fi

ln -s "$source_dir" "$target"
echo "Linked $target -> $source_dir"
