#!/bin/bash
# PRIVACY GATE lane, gate round 21: the gate-side derivation of the 17 public block-stage arrays of the REAL
# Shieldstral hate-values capture from the T128 export, all 26 blocks, with the arrays.bin SHA-256 and the 8 controls.
# Waits for Astra's first real app post (astra_wait.py), then ONE guarded cpu job, need 0.5 / cap 1.0 = the dev run's
# measured 0.33 GiB + 25% (round21/dev/dev_b1.json; pread, no mmap: the store is page cache, not RSS -- O20-1).
# No checkpoint stream, no prove, no verify. Marker: r21_chain.done (exit code of the derivation's guard).
R=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round21
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
CAP=/home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
mkdir -p $R/derive
cd /tmp
sha256sum $R/derive_block_tables.py > $R/derive/derive_block_tables.py.sha256
until python3 $R/astra_wait.py > $R/derive/astra_wait.last; do
  sleep 30
done
cp $R/derive/astra_wait.last $R/derive/astra_wait.at_launch.json
while [ -e $W ] || [ -e /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/HOLD ]; do sleep 30; done
date -u > $R/derive/launched
python3 $G run --class cpu --need-gib 0.5 --cap-gib 1.0 --label gate21-derive-26 --wait-secs 3600 --max-secs 1800 \
  --log $R/derive/derive_all.log --done $R/derive/derive_all.guard.done --result-json $R/derive/derive_all.guard.json -- \
  /usr/bin/env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 -B $R/derive_block_tables.py \
  --capture $CAP --export $EX --out $R/derive/DERIVE_ALL.json --controls
rc=$?
date -u > $R/derive/finished
echo $rc > $R/r21_chain.done
