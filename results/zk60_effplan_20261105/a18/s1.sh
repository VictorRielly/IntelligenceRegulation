#!/bin/bash
# A18 stage 1, THE PROFILE BEFORE (diagnostic): the base tree (perf a4ce8763, A16 + A17 merged). Build; the D55 harness
# at N = 6 with the phase clock in every fork and the GPU timeline (`phases`, 2 passes, proof only); then a second
# process with A11's sampler window: 3 proof-only fork calls between two handshakes with /usr/bin/sample (2 ms), as A14
# stage 1 and A17 stages 1 and 6 did. The ranking with A14's `rank.py` / `rank_detail.py`, and A17's `leaf_detail.py`
# (each bucket by its leaf frame). The raw call graph stays in raw/ (not committed). Clocks wait for a quiet GPU (no
# `ds4-bench`) and record whether one was seen. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a18
A11=$W/results/zk60_effplan_20261105/a11
A14=$W/results/zk60_effplan_20261105/a14
A17=$W/results/zk60_effplan_20261105/a17
HS=$O/raw/handshake
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
EXT='ds4-bench'
quiet() {
  local n=0
  while pgrep -f "$EXT" > /dev/null; do
    if [ $n -eq 0 ]; then say "waiting for a quiet GPU ($EXT running): $1"; fi
    n=$((n + 1))
    if [ $n -ge 480 ]; then say "GPU still busy after 4 h; $1 runs anyway (TIMING POLLUTED)"; return; fi
    sleep 30
  done
  say "GPU quiet (no $EXT): $1"
}
seen() { if pgrep -f "$EXT" > /dev/null; then say "$EXT RUNNING at the end of $1 (TIMING POLLUTED)"; else say "no $EXT at the end of $1"; fi; }
say start
mkdir -p $O/raw
$C --no-run > $O/raw/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 12 $O/raw/s1_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
quiet "phases"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_TIMELINE=1 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=2 HL_D55_GPU_AB=phases $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_d55_phases.log 2>&1
say "d55 phases + timeline rc=$?"
seen "phases"
grep -E "^D55-AB GPU-AB|^D55-AB A11|^D55-AB A12|^D55-AB SUMMARY|busy|panicked" $O/raw/s1_d55_phases.log | cut -c1-300 > $O/s1_d55_phases.log
mkdir -p $HS
rm -f $HS/go.* $HS/next.*
quiet "sample"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_A11_SAMPLE=3 HL_A11_SAMPLE_DIR=$HS $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_d55_sample.log 2>&1 &
TP=$!
PID=""
for i in $(seq 1 3600); do
  PID=$(grep -o "A11-SAMPLE READY N6 pid [0-9]*" $O/raw/s1_d55_sample.log 2>/dev/null | awk '{print $5}')
  [ -n "$PID" ] && break
  kill -0 $TP 2>/dev/null || break
  sleep 1
done
say "N6 ready pid ${PID:-none}"
if [ -n "$PID" ]; then
  /usr/bin/sample "$PID" 16 2 -mayDie -file $O/raw/s1_sample_N6.txt > $O/raw/s1_sample_N6.out 2>&1 &
  SP=$!
  sleep 2
  touch $HS/go.N6
  say "N6 go"
  wait $SP
  say "N6 sample rc=$?"
  touch $HS/next.N6
fi
wait $TP
say "d55 sample window rc=$?"
seen "sample"
grep -E "^D55-AB A11 USAGE|^A11-SAMPLE|^D55-AB SUMMARY|panicked" $O/raw/s1_d55_sample.log | cut -c1-330 > $O/s1_d55_sample.log
if [ -f $O/raw/s1_sample_N6.txt ]; then
  python3 $A11/sample_summary.py $O/raw/s1_sample_N6.txt --interval-ms 2 --top 40 --label "a18 s1 N=6, the base tree a4ce8763" > $O/s1_sample_N6.summary.txt 2>&1
  say "summary rc=$?"
  python3 $A14/rank.py $O/raw/s1_sample_N6.txt --interval-ms 2 --calls 3 > $O/s1_rank.md 2>&1
  say "rank rc=$?"
  : > $O/s1_rank_detail.txt
  : > $O/s1_leaf_detail.txt
  for b in "A/H zero-fill" "openings" "lookup" "public weight" "LogUp" "randomness" "commit host" "private slots" "per-block" "witness planes" "extension" "claimed" "transcript" "device slots" "other"; do
    python3 $A14/rank_detail.py $O/raw/s1_sample_N6.txt "$b" 15 >> $O/s1_rank_detail.txt 2>&1
    echo >> $O/s1_rank_detail.txt
  done
  for b in "A/H zero-fill" "lookup" "public weight" "LogUp" "randomness" "per-block" "witness planes" "other"; do
    python3 $A17/leaf_detail.py $O/raw/s1_sample_N6.txt "$b" 25 --interval-ms 2 --calls 3 >> $O/s1_leaf_detail.txt 2>&1
    echo >> $O/s1_leaf_detail.txt
  done
  say "details done"
  cat $O/s1_rank.md >> $P
fi
say "all done"
