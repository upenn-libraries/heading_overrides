#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$(dirname "$0")" && pwd -L )"

if [ -z "$1" ]; then
  INPUT="$(cd "$SCRIPT_DIR/../data/raw" && pwd -L )/lcsh-core.both.nt.gz"
  APPEND="$(zcat "$INPUT" | tail -n 3 | grep '^#TRAILER')"
elif [ '-' != "$1" ]; then
  INPUT="$1"
  APPEND="$(zcat "$INPUT" | tail -n 3 | grep '^#TRAILER')"
fi

if [ -n "$2" ]; then
  TMP_DIR="$2"
else
  TMP_DIR="$(mktemp -d "/tmp/duplicate_pref_labels.XXXXXXX")"
fi

echo "input \"${INPUT:-stdin}\"; output directory \"$TMP_DIR\" (step 1)" >&2

# STEP 1: selects all prefLabel triples (and stores them for use in the second step), then records all _repeated_ prefLabels (as _labels_ and counts)
(
  if [ -z "$INPUT" ]; then
    cat
  else
    zcat "$INPUT"
  fi
) | grep -F '> <http://www.w3.org/2004/02/skos/core#prefLabel> "' | grep '"@en *. *$' | grep -v -F '<http://id.loc.gov/authorities//' | tee >(gzip > "$TMP_DIR/prefLabels.nt.gz") | sort -u | cut -d ' ' -f 1 | uniq -c | grep -v -F ' 1 <' | sed 's/^ *//' | gzip > "$TMP_DIR/repeatPrefLabels.gz"

echo "input \"${INPUT:-stdin}\"; output directory \"$TMP_DIR\" (step 2)" >&2
# STEP 2: filters off duplicate &/&amp; representations, presents other repeat labels in pairs to facilitate manual correction
zgrep -v -F '<http://id.loc.gov/authorities/genreForms/' "$TMP_DIR/repeatPrefLabels.gz" | while read a b; do VAR=$(zgrep -F "$b <http://www.w3.org/2004/02/skos/core#prefLabel> \"" "$TMP_DIR/prefLabels.nt.gz" | sort | uniq -c | sort -rn); if grep -q '&amp;' <<<"$VAR"; then grep '&amp;' <<<"$VAR" | sed 's/prefLabel/wrongLabel/' | while read a b; do echo "$b"; done >> "$TMP_DIR/override_ampersands.nt"; else echo; sed 's/prefLabel/wrongLabel/' <<<"$VAR" | sed 's/^ *//'; fi; done | tee "$TMP_DIR/override_manual.nt"

if [ -n "$APPEND" ]; then
  echo "#GENERATED ($(date)) FROM:" >> "$TMP_DIR/override_ampersands.nt"
  echo "$APPEND" >> "$TMP_DIR/override_ampersands.nt"
  echo "#GENERATED ($(date)) FROM:" >> "$TMP_DIR/override_manual.nt"
  echo "$APPEND" >> "$TMP_DIR/override_manual.nt"
fi
