#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$(dirname "$0")" && pwd -L )"

INPUT="$SCRIPT_DIR/../data/raw/lcsh-core.both.nt.gz"
OUTPUT="$SCRIPT_DIR/../data/override/hidden/override_illegal_aliens.nt"

zgrep -F 'llegal alien' "$INPUT" | grep -v ' ".*--.*"@en' | grep -F '#prefLabel>' | sort -t ' ' -k 2 | uniq | while read i; do sed 's/prefLabel/hiddenLabel/' <<<"$i"; sed 's/llegal alien/ndocumented immigrant/' <<<"$i" | sed 's/Indocumented/Undocumented/' | sed 's/indocumented/undocumented/'; done > "$OUTPUT"

echo "#GENERATED ($(date)) FROM:" >> "$OUTPUT"
zcat "$INPUT" | tail -n 3 >> "$OUTPUT"
