#!/bin/bash
# Coordinator 04:35 UTC: TinyLlama LAMBADA chunks ONE at a time, after the 8B LAMBADA items 100-199.
# Wait until the deferred t_LOWv6_lam0 has passed (done marker written) and e8_LOWh8v6_lam100 has started,
# then lift the per-tag hold and append the eight chunks to lane Y (serial; lane Y waits on laneY.lock).
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/logs
until [ -f $D/L_t_LOWv6_lam0.done ] && [ -f $D/L_e8_LOWh8v6_lam100.log ]; do sleep 20; done
rm -f $D/HOLD_t_LOWv6_lam0
cat $D/pending_tl_lambada.txt >> $D/jobs_Y.txt
echo "[$(date -u +%H:%M:%SZ)] released $(wc -l < $D/pending_tl_lambada.txt) TinyLlama LAMBADA chunks to lane Y" >> $D/tl_lambada_release.out
