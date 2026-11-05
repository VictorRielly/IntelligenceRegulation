#!/bin/bash
# (1) D63 L3 finding F2: SC_LZC refuses by name a shape with more than one Dom::L helper (byte-preserving; every
#     shape has one). The full lib suite must show only the known three failures.
# (2) H124c: profile the witness builder. A loop of W16R2 8B T128 witness builds runs while macOS `sample` records
#     its call stacks for 10 s. One guarded job, class cpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/h124c.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/h124c_build.log 2>&1; say "build rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/f2_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/f2_full.log | tail -8 >> $P
env HL_H124_LOOPS=80 $C h124c_witness_build_loop_for_sampling -- --ignored --nocapture --test-threads=1 > $O/h124c_loop.log 2>&1 &
CPID=$!
for i in $(seq 1 600); do grep -q "H124c: pid" $O/h124c_loop.log 2>/dev/null && break; sleep 1; done
PID=$(grep -o "H124c: pid [0-9]*" $O/h124c_loop.log | awk '{print $3}')
say "loop pid ${PID:-none}"
sleep 6
if [ -n "${PID:-}" ]; then /usr/bin/sample "$PID" 10 -mayDie -file $O/h124c_sample.txt > $O/h124c_sample.out 2>&1; say "sample rc=$?"; fi
wait $CPID; say "loop rc=$?"
grep -E "H124c build" $O/h124c_loop.log | tail -5 >> $P
say "all done"
