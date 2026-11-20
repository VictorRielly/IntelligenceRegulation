#!/bin/bash
# After the L63 merge (perf 4a24243c, tree identical to the checked lane tree aa84f6d7): build the root once in the
# MAIN checkout, so that its Lean build directory holds the 30 RunStgShield modules and RunBlkShieldInst before the
# next lane starts there. One job under the resource guard (class cpu, default poll). It proves nothing new: the
# merged-tree verdict is results/zk60_lean_l63_20261116/check_merge.log (guard run 0217bd7d990c).
export LEAN_NUM_THREADS=4
REPO=/Users/victorrielly/IntelligenceRegulation
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
"$LAKE" -d "$REPO/formal" build ZK60Formal < /dev/null
rc=$?
echo "root build in the main checkout rc $rc, $(( $(date +%s) - start )) s"
exit $rc
