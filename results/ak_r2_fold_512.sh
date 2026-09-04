#!/bin/bash
# [UPERF3-AK] rung 2: the claim fold measured at the 125M reference shape.
B=/home/victor/wt-uperf3-ak/results/ak_hashline_fold.bin
E=/home/victor/wt-uperf3-ak/results/ak_attn_exports/m125_l0
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
G='attn-claims|attn-fold|FULL LAYER|attn-full:|Maximum resident|Elapsed'
echo "=== A: NO FOLD [the pre-fold reference] T=512 ==="
HL_NO_FOLD=1 HL_ATTN_CLAIMS=1 /usr/bin/time -v $B attn-full $E --export $V3 --t 512 --threads 8 2>&1 | grep -E "$G"
echo "=== B: FOLD sm+lm [default] T=512 ==="
HL_ATTN_CLAIMS=1 /usr/bin/time -v $B attn-full $E --export $V3 --t 512 --threads 8 2>&1 | grep -E "$G"
echo "=== C: FOLD ALL T=512 ==="
HL_FOLD_ALL=1 HL_ATTN_CLAIMS=1 /usr/bin/time -v $B attn-full $E --export $V3 --t 512 --threads 8 2>&1 | grep -E "$G"
