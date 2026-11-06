#!/bin/bash
# A18 stage 6, A13's window confirmed on the new base (the A18 defaults on): (a) a clean 2-arm A/B,
# a18def+noahead+stsl against a18def+ahead16+stsl; (b) a18def+noahead+stsl against a18def+ahead8+stsl and
# a18def+ahead16+qos1+stsl (side workers at utility quality of service, A13's best mitigation). 6 passes each,
# alternating, proof only (a control the window does not touch), one request from its input and the 4-request stream,
# every stream receipt verified after the clock. Waits for a quiet GPU. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
E=$W/results/zk60_effplan_20261105
O=$E/a18
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s6.progress
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
$C --no-run > $O/raw/s6_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
AB="env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_ALTERNATE=1 HL_D55_AB_PASSES=6 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4"
keep() { grep -E "^D55-AB GPU-AB|^D55-AB A11 USAGE|^D55-AB A13 SEALED|^D55-AB A15 SEALED|^D55-AB A15 PIPE-SEAL|^D55-AB A18|verified|panicked" "$1" | cut -c1-420 > "$2"; }
B=a18def+noahead+stsl
quiet "(a) window 16"
$AB HL_D55_GPU_AB=$B,a18def+ahead16+stsl $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s6a_d55_ab.log 2>&1
say "(a) noahead against ahead16 rc=$?"
seen "(a) window 16"
keep $O/raw/s6a_d55_ab.log $O/s6a_d55_ab.log
python3 $E/a11/pairs.py $O/raw/s6a_d55_ab.log $B a18def+ahead16+stsl --alternate --n 6 > $O/s6a_pairs.md 2>&1
python3 $E/a15/seal_pairs.py $O/raw/s6a_d55_ab.log $B a18def+ahead16+stsl --n 6 > $O/s6a_seal.md 2>&1
python3 $E/a13/seal_pairs.py $O/raw/s6a_d55_ab.log $B a18def+ahead16+stsl --n 6 > $O/s6a_seal13.md 2>&1
cat $O/s6a_pairs.md $O/s6a_seal.md >> $P
quiet "(b) window 8, window 16 at utility QoS"
$AB HL_D55_GPU_AB=$B,a18def+ahead8+stsl,a18def+ahead16+qos1+stsl $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s6b_d55_ab.log 2>&1
say "(b) noahead against ahead8 and ahead16+qos1 rc=$?"
seen "(b) window 8, window 16 at utility QoS"
keep $O/raw/s6b_d55_ab.log $O/s6b_d55_ab.log
for t in a18def+ahead8+stsl a18def+ahead16+qos1+stsl; do
  python3 $E/a11/pairs.py $O/raw/s6b_d55_ab.log $B $t --alternate --n 6 > $O/s6b_pairs_$t.md 2>&1
  python3 $E/a15/seal_pairs.py $O/raw/s6b_d55_ab.log $B $t --n 6 > $O/s6b_seal_$t.md 2>&1
  python3 $E/a13/seal_pairs.py $O/raw/s6b_d55_ab.log $B $t --n 6 > $O/s6b_seal13_$t.md 2>&1
  cat $O/s6b_pairs_$t.md >> $P
done
grep -E "A18 PIPE-MEM" $O/s6a_d55_ab.log $O/s6b_d55_ab.log | sed -E 's/.*\[([^]]*)\].*(footprint.*)/\1 \2/' >> $P
say "all done"
