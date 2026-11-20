#!/bin/bash
# Independent kernel check of lane L64 (reviewer): build ZK60Formal.RunBlkAliveR13 only (not the root), then print the
# axioms of every theorem in the file. One job under the resource guard (class cpu, default poll). Writes nothing under formal/.
export LEAN_NUM_THREADS=4
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l64_review
start=$(date +%s)
"$LAKE" -d "$REPO/formal" build ZK60Formal.RunBlkAliveR13 < /dev/null > "$OUT/l64_build.log" 2>&1
rc=$?
echo "build ZK60Formal.RunBlkAliveR13 rc $rc, $(( $(date +%s) - start )) s"
grep -c "warning" "$OUT/l64_build.log" | sed 's/^/warning lines: /'
grep -E "warning: .*RunBlkAliveR13" "$OUT/l64_build.log" | head -n 20
if [ $rc -ne 0 ]; then
  grep -E "error" "$OUT/l64_build.log" | head -n 20
  exit 1
fi
"$LAKE" -d "$REPO/formal" env lean "$OUT/l64_axioms.lean" < /dev/null > "$OUT/l64_axioms.out" 2>&1
arc=$?
echo "axioms rc $arc"
echo "axiom print lines: $(grep -c 'depends on axioms' "$OUT/l64_axioms.out")"
echo "non-standard lines: $(grep -c 'depends on axioms' "$OUT/l64_axioms.out") total; sorryAx $(grep -c sorryAx "$OUT/l64_axioms.out"); ofReduceBool $(grep -c ofReduceBool "$OUT/l64_axioms.out")"
echo "total $(( $(date +%s) - start )) s"
exit $arc
