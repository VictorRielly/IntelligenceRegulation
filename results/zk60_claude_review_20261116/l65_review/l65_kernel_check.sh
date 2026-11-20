#!/bin/bash
# Independent kernel check of lane L65 (reviewer): build the L65 top module only (not the root), then print the axioms
# of the L65 theorems. One job under the resource guard (class cpu, default poll). Writes nothing under formal/.
export LEAN_NUM_THREADS=4
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l65_review
start=$(date +%s)
"$LAKE" -d "$REPO/formal" build ZK60Formal.RunStgShieldCTopDg < /dev/null > "$OUT/l65_build.log" 2>&1
rc=$?
echo "build ZK60Formal.RunStgShieldCTopDg rc $rc, $(( $(date +%s) - start )) s"
grep -c "warning" "$OUT/l65_build.log" | sed 's/^/warning lines: /'
grep -E "warning: .*(RunStgShieldToK|RunStgShieldDg|RunStgShieldCTopDg)" "$OUT/l65_build.log" | head -n 20
if [ $rc -ne 0 ]; then
  grep -E "error" "$OUT/l65_build.log" | head -n 20
  exit 1
fi
"$LAKE" -d "$REPO/formal" env lean "$OUT/l65_axioms.lean" < /dev/null > "$OUT/l65_axioms.out" 2>&1
arc=$?
echo "axioms rc $arc"
cat "$OUT/l65_axioms.out"
echo "sorryAx lines: $(grep -c sorryAx "$OUT/l65_axioms.out"); ofReduceBool lines: $(grep -c ofReduceBool "$OUT/l65_axioms.out")"
echo "total $(( $(date +%s) - start )) s"
exit $arc
