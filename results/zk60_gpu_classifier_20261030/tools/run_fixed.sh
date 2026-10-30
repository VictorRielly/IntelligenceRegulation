#!/bin/bash
# TEST ONLY. run_fixed.sh BLOCKS -- CMD...: run CMD with /dev/urandom replaced by a FIFO holding BLOCKS
# (32-byte blocks, in draw order). Exit 97 if CMD left any block unread. An extra draw blocks; the guard's
# --max-secs ends it. Receipts made this way do not hide anything: never publish, never give to the app.
# (A5_PATCH_REVIEW.md section 4.3, byte for byte; token round 18 keeps this copy under r18/tools.)
set -u
blocks=$1; shift; [ "${1:-}" = -- ] && shift
fifo=$(mktemp -u "$(dirname "$blocks")/fifo.XXXXXX"); mkfifo -m 600 "$fifo"
exec 3<>"$fifo"            # read-write open: never blocks; keeps the pipe alive between the prover's reads
cat "$blocks" >&3
bwrap --dev-bind / / --bind "$fifo" /dev/urandom --die-with-parent -- "$@"; rc=$?
left=$(python3 -c 'import os
os.set_blocking(3, False)
try: print(len(os.read(3, 1 << 16)))
except BlockingIOError: print(0)')
exec 3<&-; rm -f "$fifo"
echo "{\"event\":\"fixed-entropy\",\"block_bytes\":$(stat -c %s "$blocks"),\"unread_bytes\":$left,\"rc\":$rc}" >&2
[ "$rc" = 0 ] || exit "$rc"; [ "$left" = 0 ] || exit 97
