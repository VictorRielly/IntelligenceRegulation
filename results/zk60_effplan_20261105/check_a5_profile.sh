#!/bin/bash
# Efficiency plan A5: profile the witness builder with the A4 device products on (HL_GPU=1). A loop of W16R2 8B T128
# witness builds runs while macOS `sample` records its call stacks for 10 s. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/a5prof.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/a5prof_build.log 2>&1; say "build rc=$?"
env HL_GPU=1 HL_H124_LOOPS=120 $C h124c_witness_build_loop_for_sampling -- --ignored --nocapture --test-threads=1 > $O/a5prof_loop.log 2>&1 &
CPID=$!
for i in $(seq 1 600); do grep -q "H124c: pid" $O/a5prof_loop.log 2>/dev/null && break; sleep 1; done
PID=$(grep -o "H124c: pid [0-9]*" $O/a5prof_loop.log | awk '{print $3}')
say "loop pid ${PID:-none}"
sleep 6
if [ -n "${PID:-}" ]; then /usr/bin/sample "$PID" 10 -mayDie -file $O/a5prof_sample.txt > $O/a5prof_sample.out 2>&1; say "sample rc=$?"; fi
wait $CPID; say "loop rc=$?"
grep -E "H124c build" $O/a5prof_loop.log | tail -5 >> $P
say "all done"
