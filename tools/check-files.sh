#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Repository checks that are not lint or tests:
#   1. every Lua file starts with the SPDX licence header
#   2. every addon Lua file is listed in the TOC (an unlisted file never loads)
# Run from the repo root: bash tools/check-files.sh
set -euo pipefail

ADDON_DIR="PerennialUI"
TOC="$ADDON_DIR/PerennialUI.toc"
HEADER="-- SPDX-License-Identifier: GPL-3.0-or-later"
status=0

while IFS= read -r file; do
    first=$(head -n 1 "$file" | tr -d '\r')
    if [ "$first" != "$HEADER" ]; then
        echo "Missing SPDX header: $file"
        status=1
    fi
done < <(find "$ADDON_DIR" tests tools -name '*.lua' -not -path "$ADDON_DIR/Libs/*" | sort)

listed=$(tr -d '\r' < "$TOC" | grep -v '^#' | grep -v '^[[:space:]]*$' | tr '\\' '/')

while IFS= read -r file; do
    relative=${file#"$ADDON_DIR"/}
    if ! grep -qxF "$relative" <<< "$listed"; then
        echo "Not listed in $TOC: $relative"
        status=1
    fi
done < <(find "$ADDON_DIR" -name '*.lua' -not -path "$ADDON_DIR/Libs/*" | sort)

while IFS= read -r entry; do
    if [ ! -f "$ADDON_DIR/$entry" ]; then
        echo "Listed in $TOC but missing: $entry"
        status=1
    fi
done <<< "$listed"

if [ "$status" -eq 0 ]; then
    echo "File checks passed."
fi
exit "$status"
