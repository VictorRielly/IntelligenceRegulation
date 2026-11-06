#!/bin/bash
# A18 stage 3, THE A/Bs on the work-in-progress tree (runs only if stage 2 printed `BYTES PASSED`). In-process D55
# harness, W16R2 8B T128, L = 32, N = 6, alternating arm order (the second arm of a pass runs about 4.5% faster):
#  (a) the forms: a18old against a18new, 6 passes, each a proof-only call, one request from its input and a 4-request
#      stream;
#  (b) the forms one by one, proof only, 8 passes: a18old, a18old+tabinv1, a18old+registry1, a18old+pubtab1, a18new;
#  (c) A13's window on the new base (the A18 forms on): a18new+noahead+stsl against a18new+ahead16+stsl and
#      a18new+ahead32+stsl (2 side workers of 6 threads), 6 passes, proof only, one request and the 4-request stream;
#      `stsl` puts every arm's stream statements on its sealing thread, which a window needs.
# Every clock waits for a quiet GPU (no `ds4-bench`) and records whether one was seen. Then the pair tables
# (`a11/pairs.py`, `a15/seal_pairs.py`, `a13/seal_pairs.py`). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
E=$W/results/zk60_effplan_20261105
O=$E/a18
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s3.progress
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
if ! grep -q "BYTES PASSED" $O/s2.progress 2>/dev/null; then
  say "stage 2 did not pass its byte tests: no A/B"
  say "all done"
  exit 1
fi
$C --no-run > $O/raw/s3_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
AB="env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_ALTERNATE=1"
keep() { grep -E "^D55-AB GPU-AB|^D55-AB A11 USAGE|^D55-AB A13 SEALED|^D55-AB A15 SEALED|^D55-AB A15 PIPE-SEAL|^D55-AB A18|^D55-AB SUMMARY|verified|panicked" "$1" | cut -c1-420 > "$2"; }
# (a) the forms together
quiet "(a) forms"
$AB HL_D55_AB_PASSES=6 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=a18old,a18new $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3a_d55_ab.log 2>&1
say "(a) a18old against a18new rc=$?"
seen "(a) forms"
keep $O/raw/s3a_d55_ab.log $O/s3a_d55_ab.log
python3 $E/a11/pairs.py $O/raw/s3a_d55_ab.log a18old a18new --alternate --n 6 > $O/s3a_pairs.md 2>&1
python3 $E/a15/seal_pairs.py $O/raw/s3a_d55_ab.log a18old a18new --n 6 > $O/s3a_seal.md 2>&1
python3 $E/a13/seal_pairs.py $O/raw/s3a_d55_ab.log a18old a18new --n 6 > $O/s3a_seal13.md 2>&1
cat $O/s3a_pairs.md $O/s3a_seal.md >> $P
# (b) the forms one by one, proof only
quiet "(b) singles"
$AB HL_D55_AB_PASSES=8 HL_D55_GPU_AB=a18old,a18old+tabinv1,a18old+registry1,a18old+pubtab1,a18new $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3b_d55_ab.log 2>&1
say "(b) singles rc=$?"
seen "(b) singles"
keep $O/raw/s3b_d55_ab.log $O/s3b_d55_ab.log
for t in a18old+tabinv1 a18old+registry1 a18old+pubtab1 a18new; do
  python3 $E/a11/pairs.py $O/raw/s3b_d55_ab.log a18old $t --alternate --n 6 > $O/s3b_pairs_$t.md 2>&1
  cat $O/s3b_pairs_$t.md >> $P
done
# (c) A13's window on the new base
quiet "(c) A13 window"
$AB HL_D55_AB_PASSES=6 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=a18new+noahead+stsl,a18new+ahead16+stsl,a18new+ahead32+stsl $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3c_d55_ab.log 2>&1
say "(c) A13 window rc=$?"
seen "(c) A13 window"
keep $O/raw/s3c_d55_ab.log $O/s3c_d55_ab.log
for t in a18new+ahead16+stsl a18new+ahead32+stsl; do
  python3 $E/a11/pairs.py $O/raw/s3c_d55_ab.log a18new+noahead+stsl $t --alternate --n 6 > $O/s3c_pairs_$t.md 2>&1
  python3 $E/a15/seal_pairs.py $O/raw/s3c_d55_ab.log a18new+noahead+stsl $t --n 6 > $O/s3c_seal_$t.md 2>&1
  python3 $E/a13/seal_pairs.py $O/raw/s3c_d55_ab.log a18new+noahead+stsl $t --n 6 > $O/s3c_seal13_$t.md 2>&1
  cat $O/s3c_pairs_$t.md $O/s3c_seal_$t.md >> $P
done
grep -E "A18 PIPE-MEM|A13 SEALED" $O/s3c_d55_ab.log | sed -E 's/.*\[([^]]*)\].*(footprint.*)/\1 \2/' | head -40 >> $P
say "all done"
