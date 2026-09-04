#!/bin/bash
# [UPERF3 lane AM rung 3, THE MISSING P1 BASELINE SCAN]
#
# WHY. rung 3's P3 arm scanned CLEAN at 8B (148 int8-class words in
# 160,959,824, ZERO runs of >= 100). That number is only meaningful against
# the SAME scan on the SAME shape's P1 proof, and rung 3's original script
# deleted the P1 proof before scanning it (`rm -f $SP/8b-p1.proof`), so the
# 8B privacy row has only one side. rung 2 has both sides but only at ONE
# Mistral layer (180,450 -> 0).
#
# This run regenerates the P1 8B proof and scans it. CPU PATH (HL_GPU unset):
# the P1 arm is what spilled the card and froze the box at ~11:06, so it does
# not get the device here. Timings from this run are NOT comparable to the
# GPU P1 row and are not quoted; the SCAN is the whole point.
set -u
R=/home/victor/wt-uperf3-am
MI=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
GPU=$R/hashline/target-gpu/release/hashline
SP=$R/results/am_scratch
WC=$SP/wcache-8b-p1scan
mkdir -p "$SP"
rm -rf "$WC"; mkdir -p "$WC"
say () { echo; echo "=== $* ==="; date '+%F %T'; free -g | head -2; }

say "FAST TIER (P1) — 8B, 32 x 512, CPU PATH (HL_GPU unset), cold weight cache"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv 2>/dev/null | head -2
/usr/bin/time -v $GPU pass 32 512 --threads 8 --zk --seed 1 \
  --profile v3 --export $MI --wcache $WC --proof-out $SP/8b-p1.proof 2>&1 \
  | grep -Ev '^      (g8|rg|a16|u16|ru|h16|rh|table slot|A masks|H masks|layout)'

say "P1 digest"
sha256sum $SP/8b-p1.proof; stat -c '%s B' $SP/8b-p1.proof

say "THE BASELINE: the clear-value scan of the 8B P1 proof"
python3 $R/results/am_r0_output_scan.py $SP/8b-p1.proof
rm -f $SP/8b-p1.proof
rm -rf "$WC"

say "DONE"
