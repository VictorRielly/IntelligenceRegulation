#!/bin/bash
# [UPERF3 lane AN rung 3] FUNCTION 2 at the 125M v3 shape on the CPU binary:
# the A/B against function 1 on the same binary in the same session (prove
# seconds and proof bytes), the ACCEPT leg, the REJECT leg (an unacceptable
# classification), and the interchange legs (a function-2 proof presented as
# function 1 and under a different predicate).
set -u
R=/home/victor/wt-uperf3-an
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CPU=$R/hashline/target/release/hashline
SP=$R/results/an_scratch
mkdir -p "$SP"

say () { echo; echo "=== $* ==="; date '+%F %T'; }

# tau = -32768 makes y - tau = y + 32768, which is in [0, 65535] for EVERY int16
# score: an always-acceptable predicate, so the A/B measures the gadget's cost and
# not a particular classification.
say "function 1 (--zk), 12x512, CPU"
$CPU pass 12 512 --threads 8 --zk --seed 1 --profile v3 --export $V3 --proof-out $SP/f1.proof 2>&1 \
  | grep -Ei 'MODE|PROVE|PASS-V3|PROOF sha256|ACCEPT|REJECT|error|panic'

say "function 2 (--predicate 0:0:-32768), 12x512, CPU"
$CPU pass 12 512 --threads 8 --predicate 0:0:-32768 --seed 1 --profile v3 --export $V3 --proof-out $SP/f2.proof 2>&1 \
  | grep -Ei 'MODE|FUNCTION 2|predicate|PROVE|PASS-V3|PROOF sha256|ACCEPT|REJECT|error|panic'

say "the two proofs, side by side"
stat -c '%n %s B' $SP/f1.proof $SP/f2.proof
python3 - "$SP/f1.proof" "$SP/f2.proof" <<'PY'
import os, sys
a, b = (os.path.getsize(p) for p in sys.argv[1:3])
print(f"function 1 {a} B; function 2 {b} B; +{b-a} B; +{100*(b/a-1):.4f}%")
PY

say "an UNACCEPTABLE classification: tau above every int16 score (must NOT verify)"
$CPU pass 12 512 --threads 8 --predicate 0:0:40000 --seed 1 --profile v3 --export $V3 2>&1 \
  | grep -Ei 'DOES NOT HOLD|PASS-V3|REJECT|ACCEPT|error|panic'

say "DONE"
