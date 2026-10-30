#!/bin/bash
# TOKEN ROUND 18, step E: the BYTE-IDENTITY TEST at real scale (A5_PATCH_REVIEW.md section 4.3, steps 2-10; step 0 ran at
# 22:38, PASS). Runs only after r18_suite.sh built the candidate (~/zk60-artifacts/token-io/r18-a5-eq/bin/...).
#   2 prepare one public post (Astra's 17-id test sentence: 3 jobs of 1 chunk)        light
#   3 its activations (Astra's writer, 3 items)                                        cpu 1.5 / 3
#   4 the batch under FIXED entropy (192 bytes: e0 r0 e1 r1 e2 r2)                     cpu 10.4 / 11.5
#   5-6 three single proves with the candidate (64 bytes each)                         cpu 10.4 / 11.5, one at a time
#   7 the r16b control for job 0 (the reviewed binary dfb8025e…, job 0's 64 bytes)     cpu 10.4 / 11.5
#   8 compare byte for byte (before any verify; digests kept)                          light
#   9 the router (must say `unverified`), then the 9 reviewed fresh checks             light, then cpu 2.9 / 7 each
#  10 the fail-closed control (normal entropy; job 1's activations empty)              cpu 10.4 / 11.5
# THE FIXED-ENTROPY RECEIPTS HIDE NOTHING: test only, never published, never given to the app, never anchored; deleted
# (with the activations and owners) by r18_eq_cleanup.sh once the comparison is recorded. Python runs with -B (no
# bytecode written into Astra's or the app's directories). Each heavy step: turn first. Marker logs/r18_eq.done.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/tools/r18_common.sh
finish() { echo "$1" > $L/r18_eq.done; step "eq end $1"; exit 0; }
R0=/home/victor/IntelligenceRegulation
A5=$R0/results/zk60_astra_20261026/a5_batch_candidate
EX=$R0/results/zk60_shieldstral_export_20261026/native_low_h24_t128
TAB=$R0/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier/token_io
WRITER=$R0/results/zk60_shieldstral_export_20261026/write_item_activations.py
VENV=$R0/apps/proven-media/.venv/bin/python
R16B=$R/cli/zk60_classify.r16b.release.bin
EQ=/home/victor/zk60-artifacts/token-io/r18-a5-eq
OWN=/home/victor/zk60-owner-private/token-io/r18-a5-eq
CAND=$EQ/bin/zk60_classify.r18-candidate
JOB=$OWN/batch
LE=$L/eq
LBL=zk60-classify-verdict
P=(shieldstral-1.0-3b-moderate-sexual/1 shieldstral-1.0-3b-moderate-violence/1 shieldstral-1.0-3b-moderate-hate/1)
mkdir -p $LE
# the two binaries' pins
echo "dfb8025eb903b203f4b50371fdd0dd00659d46a9dbaad9d121d6a68343ebc70c  $R16B" | sha256sum -c > $LE/pins.log 2>&1 || finish r16b-pin
grep " $CAND\$" $L/b18-cand.sha256 | sha256sum -c >> $LE/pins.log 2>&1 || finish candidate-pin
# step 0's directories (the entropy files exist since 22:35)
mkdir -p $EQ/batch $EQ/single $EQ/r16b $EQ/fail
mkdir -m 700 -p $OWN $OWN/single-owner $OWN/r16b-owner $OWN/fail $OWN/fail/owners $OWN/fail/empty
# 2. prepare
step prepare
$G --class light --label tio18-a5-prepare --max-secs 300 --log $LE/prepare.log --result-json $LE/prepare.guard.json -- /usr/bin/env PM_PROVER=shieldstral $VENV -B -c "import sys; sys.path.insert(0, sys.argv[1]); import batch_request as b; plan=b.proof_plans.category_work_plan(17, b.runtime.templates()); m=b.prepare_text('a5eq', 'Today I planted basil and watered the garden. The afternoon was quiet and sunny.', plan, sys.argv[2], sys.argv[3], reserved_context=b.records.screening_context()); print(len(m['jobs']), m['content_total'])" $A5 $JOB $EQ/batch
grep -qx "3 17" $LE/prepare.log || finish prepare
# 3. activations
turn 1.5; step activations
$G --class cpu --need-gib 1.5 --cap-gib 3 --label tio18-a5-act --wait-secs 14400 --max-secs 1800 --log $LE/act.log --done $LE/act.guard.done --result-json $LE/act.guard.json -- /usr/bin/env OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 $VENV -B $WRITER --request $JOB/activation-request.json --out $JOB/activations
echo $? > $LE/act.exit
[ "$(cat $LE/act.exit)" = "0" ] || finish activations
# 4. the batch, fixed entropy
turn 10.4; step batch
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio18-a5-batch --wait-secs 14400 --max-secs 3600 --log $LE/batch.log --done $LE/batch.guard.done --result-json $LE/batch.guard.json -- bash $T/tools/run_fixed.sh $EQ/ent/batch.bin -- /usr/bin/env RAYON_NUM_THREADS=8 $CAND prove-batch --export $EX --tables $TAB --content-file $JOB/content.ids --batch-file $JOB/batch-request.json --label $LBL
echo $? > $LE/batch.exit
[ "$(cat $LE/batch.exit)" = "0" ] || finish batch
# 5-6. three single proves with the candidate
for i in 0 1 2; do
  turn 10.4; step single-c$i
  $G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio18-a5-single-c$i --wait-secs 14400 --max-secs 1800 --log $LE/single-c$i.log --done $LE/single-c$i.guard.done --result-json $LE/single-c$i.guard.json -- bash $T/tools/run_fixed.sh $EQ/ent/job$i.bin -- /usr/bin/env RAYON_NUM_THREADS=8 $CAND prove --export $EX --tables $TAB --policy ${P[$i]} --content-file $JOB/content.ids --chunk 0 --seq-dir $JOB/activations/c$i --out $EQ/single/c$i --owner-dir $OWN/single-owner/c$i --label $LBL
  echo $? > $LE/single-c$i.exit
  [ "$(cat $LE/single-c$i.exit)" = "0" ] || finish single-c$i
done
# 7. the r16b control for job 0
turn 10.4; step r16b-c0
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio18-a5-r16b-c0 --wait-secs 14400 --max-secs 1800 --log $LE/r16b-c0.log --done $LE/r16b-c0.guard.done --result-json $LE/r16b-c0.guard.json -- bash $T/tools/run_fixed.sh $EQ/ent/job0.bin -- /usr/bin/env RAYON_NUM_THREADS=8 $R16B prove --export $EX --tables $TAB --policy ${P[0]} --content-file $JOB/content.ids --chunk 0 --seq-dir $JOB/activations/c0 --out $EQ/r16b/c0 --owner-dir $OWN/r16b-owner/c0 --label $LBL
echo $? > $LE/r16b-c0.exit
[ "$(cat $LE/r16b-c0.exit)" = "0" ] || finish r16b-c0
# 8. compare (before any verify: verify writes into the run directory)
step compare
$G --class light --label tio18-a5-compare --max-secs 1200 --log $LE/compare.log --result-json $LE/compare.guard.json -- python3 $T/tools/compare.py $EQ $OWN --digests $LE/digests.json
echo $? > $LE/compare.exit
[ "$(cat $LE/compare.exit)" = "0" ] || finish compare
# 9. the router, then the fresh checks
step router
$G --class light --label tio18-a5-router --max-secs 120 --log $LE/router.log --result-json $LE/router.guard.json -- /usr/bin/env PM_PROVER=shieldstral $VENV -B -c "import json,sys; sys.path.insert(0, sys.argv[1]); import batch_request as b; m=json.load(open(sys.argv[2]+'/batch-request.json')); out=''.join(l for l in open(sys.argv[3]) if l.startswith('{\"event\"') and 'fixed-entropy' not in l); print(b.split_unverified_log(out, 0, m, 17)['status'])" $A5 $JOB $LE/batch.log
grep -qx "unverified" $LE/router.log || finish router
$G --class light --label tio18-a5-fresh-list --max-secs 120 --log $LE/fresh-list.log --result-json $LE/fresh-list.guard.json -- /usr/bin/env PM_PROVER=shieldstral $VENV -B $T/tools/fresh_checks.py list $A5 $JOB 17 $LE/fresh_cmds.json
[ -s $LE/fresh_cmds.json ] || finish fresh-list
step fresh-checks
python3 $T/tools/fresh_checks.py run $LE/fresh_cmds.json $LE $LE/fresh_result.json > $LE/fresh-run.log 2>&1 || finish fresh-checks
# 10. the fail-closed control (normal entropy)
python3 $T/tools/make_fail_request.py $JOB/batch-request.json $OWN/fail $EQ/fail || finish fail-request
turn 10.4; step failclosed
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio18-a5-failclosed --wait-secs 14400 --max-secs 2400 --log $LE/fail.log --done $LE/fail.guard.done --result-json $LE/fail.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $CAND prove-batch --export $EX --tables $TAB --content-file $JOB/content.ids --batch-file $OWN/fail/batch-request.json --label $LBL
echo $? > $LE/fail.exit
python3 $T/tools/fail_check.py $LE/fail.log $LE/fail.guard.json $EQ/fail $OWN/fail/owners $LE/fail_check.json > $LE/fail_check.log 2>&1 || finish failclosed
finish 0
