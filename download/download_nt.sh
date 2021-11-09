#!/usr/bin/env bash

DOWNLOAD_SCRIPT_DIR="$( cd "$(dirname "$0")" && pwd -L )"

if type 'sha1' >/dev/null 2>&1; then
  # e.g., MacOS
  SHA1_UTILITY="sha1"
elif type 'sha1sum' >/dev/null 2>&1; then
  # e.g., standard Linux
  SHA1_UTILITY="sha1sum"
else
  echo "unable to determine sha1 utility" >&2
  exit 1
fi

# we actually do not use this (because we need to inline it so we can generate two
# different checksums; but we leave it here for clarity wrt what's going on
append_trailer() {
  FIFO="$(mktemp -u)"
  mkfifo "$FIFO"
  exec 3<> "$FIFO"
  rm "$FIFO"
  tee >("$SHA1_UTILITY" >&3; exec 3>&-) | cat - <(
    read hash b <&3;
    echo "#${1:-TRAILER} sha1=$hash ($(date))"
  )
}

case "$1" in
  'lcnaf')
    TYPE='lcnaf'
    ;;
  'lcsh')
    TYPE='lcsh'
    ;;
  *)
    echo "type \"$1\" not recognized" >&2
    exit 1
    ;;
esac

CURL_ARGS=("https://lds-downloads.s3.amazonaws.com/${TYPE}.both.nt.zip")

if [ -z "$2" ]; then
  OUTPUT="$(cd "$DOWNLOAD_SCRIPT_DIR/../data/raw" && pwd -L)/$TYPE-core.both.nt.gz"
elif [ '-' != "$2" ]; then
  OUTPUT="$2"
  if [[ "$OUTPUT" != *.gz ]]; then
    echo "WARNING: output is gzipped, but specified output file does not have .gz extention!" >&2
  fi
else
  CURL_ARGS=('-s' "${CURL_ARGS[@]}")
fi

echo "writing $TYPE output to ${OUTPUT:-stdout}" >&2

REMOVE_ANONYMOUS_NODES='\(^_:\|> _:\)'

write_trailer() {
  read sha1 discard
  echo "#TRAILER ${1:-sha1}=${sha1}"
}

# NOTE: suppress `gunzip` error output because we know that `gunzip` will choke on the zip
# archive trailer, and that's ok.
# we also jump through hoops here to append trailers that include the retrieval date and
# sha1 of the original downloaded file and the pruned (saved) file
FIFO1="$(mktemp -u)"
FIFO2="$(mktemp -u)"
mkfifo "$FIFO1"
mkfifo "$FIFO2"
exec 3<> "$FIFO1"
exec 4<> "$FIFO2"
rm "$FIFO1"
rm "$FIFO2"
curl "${CURL_ARGS[@]}" | gunzip 2>/dev/null | tee >("$SHA1_UTILITY" >&3) | grep -v "$REMOVE_ANONYMOUS_NODES" | grep -F -f "$DOWNLOAD_SCRIPT_DIR/${TYPE}_allow_patterns.txt" | tee >("$SHA1_UTILITY" >&4) | cat - <(write_trailer 'orig_sha1' <&3) <(write_trailer 'pruned_sha1' <&4) <(echo "#TRAILER date=$(date)") | (
  if [ -z "$OUTPUT" ]; then
    cat
  else
    gzip > "$OUTPUT"
  fi
)
exec 3>&-
exec 4>&-
