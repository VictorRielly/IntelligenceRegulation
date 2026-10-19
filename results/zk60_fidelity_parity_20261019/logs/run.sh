#!/bin/bash
# usage: run.sh LABEL NEED_GIB CAP_GIB MAXSECS MODEL -- fp_eval args...
# one guarded light job (4 BLAS threads); log/done/guard json under logs/
L=$1; NEED=$2; CAP=$3; MAXS=$4; MODEL=$5; shift 5
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib $NEED --cap-gib $CAP \
  --label fp-$L --wait-secs 14400 --max-secs $MAXS --log $D/logs/$L.log --done $D/logs/$L.guarddone \
  --result-json $D/logs/$L.guard.json -- /usr/bin/env OPENBLAS_NUM_THREADS=4 ZK60_MODEL=$MODEL python3 "$@"
echo $? > $D/logs/$L.done
