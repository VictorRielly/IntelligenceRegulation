#!/bin/bash
# S4 design check: rebuild Sol's four isolated sources and the reviewer's own
# harness against the pinned R13 rlib (outputs into this scratch dir only),
# run them, and diff Sol's printed results. Run as ONE guarded light job.
set -u
S=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/s4-split-width
O=/home/victor/IntelligenceRegulation/ops/zkp-mvp/s4-design-check-scratch
DEPS=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/working-tree/hashline/target/release/deps
RLIB=$DEPS/libhashline-779e537f6d239754.rlib
RUSTC=/home/victor/.cargo/bin/rustc
mkdir -p "$O/bin" "$O/out"
echo "rlib $(sha256sum "$RLIB" | cut -c1-64)"
rc=0
for src in algebra scalar_split; do
  "$RUSTC" --edition=2021 "$S/$src.rs" -O -o "$O/bin/$src" 2> "$O/out/$src.build.err" || { echo "BUILD FAIL $src"; rc=1; }
done
for src in pcs_lift cfs_lift; do
  "$RUSTC" --edition=2021 "$S/$src.rs" -O -L "dependency=$DEPS" --extern "hashline=$RLIB" -o "$O/bin/$src" 2> "$O/out/$src.build.err" || { echo "BUILD FAIL $src"; rc=1; }
done
"$RUSTC" --edition=2021 "$O/s4_gate_check.rs" -O -L "dependency=$DEPS" --extern "hashline=$RLIB" -o "$O/bin/s4_gate_check" 2> "$O/out/s4_gate_check.build.err" || { echo "BUILD FAIL s4_gate_check"; rc=1; }
for b in algebra scalar_split pcs_lift cfs_lift s4_gate_check; do
  [ -x "$O/bin/$b" ] || continue
  /usr/bin/env RAYON_NUM_THREADS=2 HL_GPU=0 "$O/bin/$b" > "$O/out/$b.out" 2> "$O/out/$b.err"; echo "run $b exit $?"
done
# Sol's printed JSON summary lines vs mine (last line of each)
for pair in algebra:s4-algebra-run-2 scalar_split:s4-scalar-run-1 pcs_lift:s4-pcs-lift-run-1 cfs_lift:s4-cfs-lift-run-4; do
  b=${pair%%:*}; l=${pair##*:}
  if [ "$(grep '^{' "$S/$l.log" | tail -1)" = "$(grep '^{' "$O/out/$b.out" | tail -1)" ]; then echo "SAME summary $b"; else echo "DIFF summary $b"; rc=1; fi
done
if cmp -s <(grep '^rejected' "$S/s4-cfs-lift-run-4.log") <(grep '^rejected' "$O/out/cfs_lift.out"); then echo "SAME cfs_lift rejection lines"; else echo "DIFF cfs_lift rejection lines"; fi
exit $rc
