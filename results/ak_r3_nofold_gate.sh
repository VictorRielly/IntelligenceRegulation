#!/bin/bash
# [UPERF3-AK] rung 3 gate: with HL_NO_FOLD=1 the folded tree must still
# reproduce AG's pre-fold 12-layer digest c91f8713.. BYTE FOR BYTE — proof
# that the claim fold is the only thing that moved.
B=/home/victor/wt-uperf3-ak/hashline/target/release/hashline
E=/home/victor/wt-uperf3-ak/results/ak_attn_exports
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
HL_NO_FOLD=1 $B attn-pass $E/m125_l 12 --export $V3 --t 512 --threads 8 2>&1 | grep -E "PROOF sha256|PASS-FULL"
