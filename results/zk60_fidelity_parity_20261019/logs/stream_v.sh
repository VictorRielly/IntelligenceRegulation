#!/bin/bash
# stream V: TinyLlama calibration variants (builds + evals), then the entries deferred from stream T2.
# One guarded light job at a time; runs beside stream T1 only (lane total <= ~5.5 GiB).
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T128
C=fineweb:48,wikitext:48
for f in $D/logs/ab8_abl_base.done $D/logs/abA_abl_exp.done $D/logs/abB_abl_uh.done; do until [ -f $f ]; do sleep 20; done; done
echo "[$(date -u +%H:%M:%SZ)] stream V released"
g() {  # g LABEL NEED -- cmd...
  L=$1; N=$2; shift 3
  if [ -f $D/logs/V_$L.done ] && [ "$(cat $D/logs/V_$L.done)" = "0" ]; then echo "skip $L"; return; fi
  echo "[$(date -u +%H:%M:%SZ)] start $L"
  python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib $N --cap-gib $(python3 -c "print($N+1)") \
    --label fp-V_$L --wait-secs 21600 --max-secs 10800 --log $D/logs/V_$L.log --done $D/logs/V_$L.guarddone \
    --result-json $D/logs/V_$L.guard.json -- /usr/bin/env OPENBLAS_NUM_THREADS=4 ZK60_MODEL=tinyllama FP_ALLOW=1 "$@"
  echo $? > $D/logs/V_$L.done
  echo "[$(date -u +%H:%M:%SZ)] end $L exit $(cat $D/logs/V_$L.done)"
}
build() { [ -f $D/variants/$1/profile.json ] || g build_$1 2 -- python3 $D/fp_variant.py --name "$@"; }
evalv() { T=$1; V=$2; shift 2; [ -f $D/runs/tinyllama/$T/summary.json ] || g $T 2.5 -- python3 $D/fp_eval.py --export $D/variants/$V --corpora $C --tag $T "$@"; }
build tl_dg --variant dg
evalv var_dg tl_dg
build tl_dg_w16 --variant dg --window qkv:16,g:16,z:16
evalv var_dg_w16 tl_dg_w16
build tl_pg_w16 --variant pg --window qkv:16,g:16,z:16
evalv var_pg_w16 tl_pg_w16
# entries deferred from stream T2 (released once T2 has passed them)
until grep -q "stream T2 finished" $D/logs/stream_T2.out 2>/dev/null; do sleep 20; done
rm -f $D/logs/HOLD_wi_gatepc8sat $D/logs/HOLD_fix_pround $D/logs/HOLD_abl_ffn_core $D/logs/HOLD_abl_w_attn $D/logs/HOLD_abl_w_ffn $D/logs/HOLD_abl_softmax $D/logs/HOLD_abl_all
for spec in "wi_gatepc8sat|--gate-pc -8:sat" "fix_pround|--mods pround" "abl_ffn_core|--relax ffn_core" "abl_softmax|--relax softmax" "abl_w_attn|--relax w_attn" "abl_w_ffn|--relax w_ffn" "abl_all|--relax all"; do
  T=${spec%%|*}; X=${spec#*|}
  [ -f $D/runs/tinyllama/$T/summary.json ] || g $T 2.5 -- python3 $D/fp_eval.py --export $E --corpora $C --tag $T $X
done
echo "[$(date -u +%H:%M:%SZ)] stream V finished"
