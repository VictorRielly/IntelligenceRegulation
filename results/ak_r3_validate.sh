#!/bin/bash
# [UPERF3-AK] rung 3: the full-layer statement re-validated WITH the claim
# fold on — every tamper leg, the 12-layer full-model pass, and the
# Mistral layer.
B=/home/victor/wt-uperf3-ak/hashline/target/release/hashline
E=/home/victor/wt-uperf3-ak/results/ak_attn_exports
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
MV3=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
G='FULL LAYER|attn-layer:|attn-full:|attn-pass:|tamper|PROOF sha256|PASS-FULL|ACCEPTED|Maximum resident|Elapsed|layer  '

echo "=== 1. 125M attn-full T=512, all tampers ==="
/usr/bin/time -v $B attn-full $E/m125_l0 --export $V3 --t 512 --threads 8 --all-tampers 2>&1 | grep -E "$G"
echo "=== 2. 125M attn-layer T=512, all tampers (the attention half alone, 12 legs) ==="
/usr/bin/time -v $B attn-layer $E/m125_l0 --t 512 --threads 8 --all-tampers 2>&1 | grep -E "$G"
echo "=== 3. Mistral attn-full T=16, all tampers ==="
/usr/bin/time -v $B attn-full $E/mistral_l0 --export $MV3 --t 16 --threads 8 --all-tampers 2>&1 | grep -E "$G"
echo "=== 4. THE 12-LAYER 125M FULL-MODEL PASS, folded, with the layer-seam leg ==="
/usr/bin/time -v $B attn-pass $E/m125_l 12 --export $V3 --t 512 --threads 8 --all-tampers 2>&1 | grep -E "$G"
