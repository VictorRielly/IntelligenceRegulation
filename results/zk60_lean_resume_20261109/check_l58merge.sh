#!/bin/bash
# 2026-11-12, coordinator. Lane L58 (the input endpoint's checked column/opening extractor on the code's
# header; Merkle tag + canonical-word refusal check; ex_productionReadyL_epP_codeH) on the MERGED tree in the
# main checkout, as one guarded cpu job: check_lean_merge.sh (full build, axiom audits L9..L58, source scan,
# regressions), then L58's own 4 generators (8 generated files compared byte-for-byte and restored),
# l58_tagcheck.py (with negative control), and lane L51's RunAbsCheck.lean agreement check.
# Every command reads /dev/null (L49-FZC-1).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l58_20261110
O51=$R/results/zk60_lean_l51_20261110
L=$R/formal/ZK60Formal
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l58 \
  RunEpXExt.lean RunEpXOpW.lean RunEpXInc.lean RunEpXTest.lean \
  RunEpXTop.lean RunEpXTopT.lean RunEpXTopW.lean RunEpXTopX.lean \
  RunEpXTopF.lean RunEpXTopG.lean RunEpXMk.lean RunEpXTopH.lean < /dev/null
mrc=$?
P=$O/l58merge.progress
X=$O/l58merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "check_lean_merge.sh rc=$mrc"
say "L58's own steps start"
GENF="RunEpXInc RunEpXTop RunEpXTopT RunEpXTopW RunEpXTopX RunEpXTopF RunEpXTopG RunEpXTopH"
GENS="l58_mk_inc.py l58_mk_chain.py l58_mk_topG.py l58_mk_topH.py"
gok=0
for f in $GENF; do cp "$L/$f.lean" "${X}_saved_$f.lean"; done
for g in $GENS; do
  python3 -I "$O/$g" "$R" < /dev/null > "${X}_gen_$g.log" 2>&1; grc=$?
  say "generator $g rc=$grc"
  [ $grc -eq 0 ] || gok=1
done
for f in $GENF; do
  cmp -s "${X}_saved_$f.lean" "$L/$f.lean"; crc=$?
  cp "${X}_saved_$f.lean" "$L/$f.lean"
  rm -f "${X}_saved_$f.lean"
  say "$f.lean identical to its generator output (cmp rc 0 = identical): rc=$crc"
  [ $crc -eq 0 ] || gok=1
done
python3 -I "$O/l58_tagcheck.py" "$R" < /dev/null > "${X}_tagcheck.log" 2>&1; trc=$?
say "l58_tagcheck.py (input Merkle tag + canonical-word refusal, with negative control) rc=$trc"
grep -E '^L58 tag check' "${X}_tagcheck.log" >> $P
ulimit -s 65520
"$LAKE" -d "$R/formal" env lean --run "$L/RunAbsCheck.lean" "$O51/l51_corpus.txt" "$R/ops/zkp-mvp/gpu-metal" < /dev/null > "${X}_abscheck.log" 2>&1; arc=$?
tail -n 1 "${X}_abscheck.log" >> $P
aok=1
grep -q '^RunAbsCheck: 29 checks, 0 failed$' "${X}_abscheck.log" && aok=0
say "RunAbsCheck.lean rc=$arc verdict=$aok"
say "all done (L58) mrc=$mrc gok=$gok trc=$trc arc=$arc aok=$aok"
if [ $mrc -eq 0 ] && [ $gok -eq 0 ] && [ $trc -eq 0 ] && [ $arc -eq 0 ] && [ $aok -eq 0 ]; then
  rm -f ${X}_*.log "$O"/l58merge_*.log
  exit 0
fi
exit 1
