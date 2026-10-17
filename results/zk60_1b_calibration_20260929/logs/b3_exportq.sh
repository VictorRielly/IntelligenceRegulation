#!/bin/bash
# Lane B3 export queue: b3_exportq.sh <variant[:rotseed]>... (sequential guarded runs)
D=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929
for spec in "$@"; do
  v=${spec%%:*}
  if [ "$spec" != "$v" ]; then $D/logs/b3_export.sh $v ${spec##*:}; else $D/logs/b3_export.sh $v; fi
done
