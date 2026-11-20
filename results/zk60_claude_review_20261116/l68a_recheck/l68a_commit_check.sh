#!/bin/bash
# Check before committing lane L68a (RunShieldBlkInst.lean, written by the Antigravity co-coordinator; committed by
# Claude on 2026-11-18 while Antigravity is out of credits, after removing one redundant `rfl`).
# Steps: (1) build the module, (2) build the whole root, (3) print the axioms of the file's public theorems from a
# scratch file that imports the root. Exit 0 only if all three are clean. One guarded job, class build.
export LEAN_NUM_THREADS=4
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$REPO/results/zk60_claude_review_20261116/l68a_recheck
start=$(date +%s)
echo "== source hash =="
shasum -a 256 "$REPO/formal/ZK60Formal/RunShieldBlkInst.lean" "$REPO/formal/ZK60Formal.lean"
echo "== (1) lake build ZK60Formal.RunShieldBlkInst =="
"$LAKE" -d "$REPO/formal" build ZK60Formal.RunShieldBlkInst < /dev/null > "$OUT/commit_modbuild.log" 2>&1
mrc=$?
echo "module build rc $mrc; error lines: $(grep -c 'error' "$OUT/commit_modbuild.log"); warnings naming the file: $(grep -c 'warning: .*RunShieldBlkInst\.lean' "$OUT/commit_modbuild.log")"
if [ $mrc -ne 0 ]; then grep -E 'error' "$OUT/commit_modbuild.log" | head -n 20; exit 1; fi
echo "== (2) lake build ZK60Formal (whole root) =="
"$LAKE" -d "$REPO/formal" build ZK60Formal < /dev/null > "$OUT/commit_rootbuild.log" 2>&1
rrc=$?
echo "root build rc $rrc; error lines: $(grep -c 'error' "$OUT/commit_rootbuild.log")"
if [ $rrc -ne 0 ]; then grep -E 'error' "$OUT/commit_rootbuild.log" | head -n 20; exit 1; fi
echo "== (3) axioms, from a scratch file importing the whole root =="
cat > "$OUT/commit_axioms.lean" <<'EOF'
import ZK60Formal
#print axioms ZK60.ProtocolClassify.shdP_hzk
#print axioms ZK60.ProtocolClassify.shdP_bitLay_layR
#print axioms ZK60.ProtocolClassify.shdP_bitLay_dPos
#print axioms ZK60.ProtocolClassify.shdP_blkParams_shieldBlkAtD
#print axioms ZK60.ProtocolClassify.shdP_clampPk_Pk0
#print axioms ZK60.ProtocolClassify.shdP_blks_length
#print axioms ZK60.ProtocolClassify.shdP_blk_cal_eq
#print axioms ZK60.ProtocolClassify.shdP_Pk0_eq_blkParams
#print axioms ZK60.ProtocolClassify.shdP_shieldRunAtD
#print axioms ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkLu
#print axioms ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldLu
EOF
"$LAKE" -d "$REPO/formal" env lean "$OUT/commit_axioms.lean" < /dev/null > "$OUT/commit_axioms.out" 2>&1
arc=$?
n=$(grep -c "depends on axioms" "$OUT/commit_axioms.out")
bad=$(grep "depends on axioms" "$OUT/commit_axioms.out" | grep -v -E "depends on axioms: \[(propext, )?(Classical\.choice, )?Quot\.sound\]$" | wc -l | tr -d ' ')
sorry=$(grep -c -E "sorryAx|error" "$OUT/commit_axioms.out")
echo "axioms rc $arc; declarations printed: $n of 11; outside propext/Classical.choice/Quot.sound: $bad; sorryAx or error lines: $sorry"
echo "== sorry / axiom / admit in the source =="
src=$(grep -c -E "\bsorry\b|^axiom |\badmit\b" "$REPO/formal/ZK60Formal/RunShieldBlkInst.lean")
echo "source lines with sorry, axiom or admit: $src"
echo "wall $(( $(date +%s) - start )) s"
if [ $arc -eq 0 ] && [ "$n" = "11" ] && [ "$bad" = "0" ] && [ "$sorry" = "0" ] && [ "$src" = "0" ]; then
  echo "VERDICT: green"; exit 0
fi
echo "VERDICT: RED"; exit 1
