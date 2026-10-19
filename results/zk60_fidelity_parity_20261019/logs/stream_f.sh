#!/bin/bash
# stream F: TinyLlama full metric set (task 2) after stream T1, then T1's deferred ablations.
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T128
until grep -q "stream T1 finished" $D/logs/stream_T1.out 2>/dev/null; do sleep 20; done
echo "[$(date -u +%H:%M:%SZ)] stream F released"
run() { T=$1; C=$2; N=$3; shift 3
  [ -f $D/runs/tinyllama/$T/summary.json ] && { echo "skip $T"; return; }
  echo "[$(date -u +%H:%M:%SZ)] start $T"
  python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib $N --cap-gib $(python3 -c "print($N+1)") \
    --label fp-F_$T --wait-secs 21600 --max-secs 14400 --log $D/logs/F_$T.log --done $D/logs/F_$T.guarddone \
    --result-json $D/logs/F_$T.guard.json -- /usr/bin/env OPENBLAS_NUM_THREADS=4 ZK60_MODEL=tinyllama FP_ALLOW=1 \
    python3 $D/fp_eval.py --export $E --corpora $C --tag $T "$@"
  echo $? > $D/logs/F_$T.done; echo "[$(date -u +%H:%M:%SZ)] end $T exit $(cat $D/logs/F_$T.done)"; }
run full_ppl fineweb:128,wikitext:128 2.5
for o in 0 250 500 750; do run full_lam$o lambada:250@$o 2.5; done
rm -f $D/logs/HOLD_abl_o $D/logs/HOLD_abl_rope $D/logs/HOLD_abl_attn_core
for spec in "abl_o|--relax o" "abl_rope|--relax rope" "abl_attn_core|--relax attn_core"; do
  run ${spec%%|*} fineweb:48,wikitext:48 2.5 ${spec#*|}
done
echo "[$(date -u +%H:%M:%SZ)] stream F finished"
