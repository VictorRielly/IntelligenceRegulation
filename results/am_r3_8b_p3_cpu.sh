#!/bin/bash
# [UPERF3 lane AM rung 3, P3 ARM ONLY — the salvage re-run of 2026-09-04 11:0x]
#
# WHY THIS SCRIPT EXISTS. am_r3_8b.sh runs both tiers back to back. On
# 2026-09-04 its FAST TIER (P1) arm completed GREEN and reproduced the round-14
# product number byte for byte (930ce9a0.. / 1,285,578,368 B, prove 238.37 s),
# and then the FULL TIER (P3) arm died two layers in when THE BOX FROZE at
# ~11:06 — the third VRAM hard stop of the day. The P1 arm spills an 8,188 MB
# card (8,585 MB working set) and the kernel logged
# `dxgkio_make_resident: Ioctl failed: -12` every ~2 min all the way through it;
# three seconds after it exited the card was still full enough that P3's opening
# commit could not get 378 MB, let alone its 5,387 MB hiding-W commitment.
#
# SO THIS ARM RUNS WITH THE GPU OFF (HL_GPU unset -> gpu::enabled() false).
# It cannot ask for device memory, so it cannot freeze the box. The SAME
# target-gpu binary is used, so the one-binary property of rung 3 is kept.
# What this buys: the full tier's PRIVACY and INTEGRITY claims at 8B (the
# digest, the size, the clear-value scan) at zero risk. What it does NOT buy:
# a P3-on-GPU 8B time. That row needs a card that can hold 5,387 MB beside the
# pass working set — i.e. the 16 GB+ board — and stays booked there.
#
# DO NOT quote this arm's seconds against a P1-on-GPU row. Same trap as rung 2.
set -u
R=/home/victor/wt-uperf3-am
MI=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
GPU=$R/hashline/target-gpu/release/hashline
SP=$R/results/am_scratch
mkdir -p "$SP"
say () { echo; echo "=== $* ==="; date '+%F %T'; free -g | head -2; }

say "FULL TIER (P3) — 8B, 32 x 512, CPU PATH (HL_GPU unset), no cache (refused by the mode)"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv 2>/dev/null | head -2
/usr/bin/time -v $GPU pass 32 512 --threads 8 --p3 --seed 1 \
  --profile v3 --export $MI --proof-out $SP/8b-p3.proof 2>&1 \
  | grep -Ev '^      (g8|rg|a16|u16|ru|h16|rh|table slot|A masks|H masks|layout)'

say "P3 digest"
sha256sum $SP/8b-p3.proof; stat -c '%s B' $SP/8b-p3.proof

say "the clear-value scan of the 8B P3 proof"
python3 $R/results/am_r0_output_scan.py $SP/8b-p3.proof
rm -f $SP/8b-p3.proof

say "DONE"
