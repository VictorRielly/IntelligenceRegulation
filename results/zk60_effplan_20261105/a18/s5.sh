#!/bin/bash
# A18 stage 5 (diagnostic): why the TABINV and PUBTAB forms measured slower in stage 3 (b). The phase clock in every
# fork (`phases`), proof only, 4 passes alternating: a18old, a18old+tabinv1, a18old+pubtab1, a18old+registry1. The
# per-block phase rows of each arm are compared by `phase_table.py`. Waits for a quiet GPU. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
E=$W/results/zk60_effplan_20261105
O=$E/a18
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s5.progress
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
$C --no-run > $O/raw/s5_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
quiet "phases"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_ALTERNATE=1 HL_D55_AB_PASSES=4 HL_D55_GPU_AB=a18old+phases,a18old+tabinv1+phases,a18old+tabinv1+tabpar1+phases,a18old+pubtab1+phases,a18old+registry1+phases $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s5_d55_phases.log 2>&1
say "phases rc=$?"
seen "phases"
grep -E "^D55-AB GPU-AB|^D55-AB A11|panicked" $O/raw/s5_d55_phases.log | cut -c1-300 > $O/s5_d55_phases.log
python3 $O/phase_table.py $O/raw/s5_d55_phases.log a18old+phases a18old+tabinv1+phases a18old+tabinv1+tabpar1+phases a18old+pubtab1+phases a18old+registry1+phases > $O/s5_phase_table.md 2>&1
cat $O/s5_phase_table.md >> $P
# each form against the code before A18 in a 2-arm A/B (proof only, 6 passes, alternating), so no form is read
# only from a 5-arm sequence
for t in tabinv1 tabinv1+tabpar1 pubtab1 registry1 tabinv1+registry1; do
  quiet "pair $t"
  env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_ALTERNATE=1 HL_D55_AB_PASSES=6 HL_D55_GPU_AB=a18old,a18old+$t $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s5_pair_$t.log 2>&1
  say "pair a18old against a18old+$t rc=$?"
  seen "pair $t"
  grep -E "^D55-AB GPU-AB|^D55-AB A11 USAGE|panicked" $O/raw/s5_pair_$t.log | cut -c1-300 > $O/s5_pair_$t.log
  python3 $E/a11/pairs.py $O/raw/s5_pair_$t.log a18old a18old+$t --alternate --n 6 > $O/s5_pairs_$t.md 2>&1
  grep -E "^#|proof wall|forks phase|user CPU|sys CPU" $O/s5_pairs_$t.md >> $P
done
# A11's per-fork pool width re-swept on this base (the existing arm words; no code): fpauto (the default rule,
# ceil(32 / 6) = 6) against fp4 and fp5, proof only, one request and the 4-request stream, 6 passes
quiet "fork pools"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_ALTERNATE=1 HL_D55_AB_PASSES=6 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=fpauto,fp4,fp5 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s5_pools.log 2>&1
say "fork pools fpauto, fp4, fp5 rc=$?"
seen "fork pools"
grep -E "^D55-AB GPU-AB|^D55-AB A11 USAGE|^D55-AB A13 SEALED|^D55-AB A15 SEALED|^D55-AB A15 PIPE-SEAL|panicked" $O/raw/s5_pools.log | cut -c1-300 > $O/s5_pools.log
for t in fp4 fp5; do
  python3 $E/a11/pairs.py $O/raw/s5_pools.log fpauto $t --alternate --n 6 > $O/s5_pairs_pools_$t.md 2>&1
  python3 $E/a15/seal_pairs.py $O/raw/s5_pools.log fpauto $t --n 6 > $O/s5_seal_pools_$t.md 2>&1
  cat $O/s5_pairs_pools_$t.md >> $P
done
say "all done"
