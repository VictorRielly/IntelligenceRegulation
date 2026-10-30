#!/bin/bash
# TOKEN ROUND 19, after r19_suite.sh built the candidate (~/zk60-artifacts/token-io/r19/bin/zk60_classify.r19-candidate):
#  1. rung receipts cross-verify between the r19 candidate and the r18 binary 110f0c53…, both ways (round 15's
#     two-binary test; cpu 1.0 / 2.0)
#  2. the REAL moderate-hate receipt (r16-runs/hate-run, made by e94cecf9…) re-verified by the candidate, each in a
#     fresh process (cpu 2.9 / 4.5, as round 18): (a) ZK60_MODELS unset (the HOME branch: today's path),
#     (b) ZK60_MODELS=/home/victor/models (the variable's branch, same file), (c) ZK60_MODELS naming a directory that
#     does not exist (must be REFUSED, exit != 0, naming it). The receipt directory is hashed before and after each:
#     a verify must leave every byte unchanged.
#  3. RECEIPT BYTES UNCHANGED at real scale: the candidate's single prove of job 0 (moderate sexual, Astra's public
#     17-id sentence) under round 18's FIXED PUBLIC entropy job0.bin = round 18's recorded single / batch / r16b job-0
#     digests (30 files). Test-only receipt: hides nothing, never published, deleted after the comparison (~0.97 GB).
# Each heavy step: turn first. Marker logs/r19_check.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19/tools/r19_common.sh
finish() { echo "$1" > $L/r19_check.done; step "check end $1"; exit 0; }
R0=/home/victor/IntelligenceRegulation
EX=$R0/results/zk60_shieldstral_export_20261026/native_low_h24_t128
TAB=$R0/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier/token_io
A5=$R0/results/zk60_astra_20261026/a5_batch_candidate
WRITER=$R0/results/zk60_shieldstral_export_20261026/write_item_activations.py
VENV=$R0/apps/proven-media/.venv/bin/python
EQ=/home/victor/zk60-artifacts/token-io/r19
OWN=/home/victor/zk60-owner-private/token-io/r19
CAND=$EQ/bin/zk60_classify.r19-candidate
B18=$R/cli/zk60_classify.r18.release.bin
HATE=/home/victor/zk60-artifacts/token-io/r16-runs/hate-run
ID=29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1
RF=$R/r18/tools/run_fixed.sh
LB=$L/bytes
JOB=$OWN/batch
LBL=zk60-classify-verdict
mkdir -p $LB
echo "110f0c53c56f691c301fe4f47d13afc1ccc9898efbaaf8506f1e0d5cde5f4496  $B18" | sha256sum -c > $L/check-pins.log 2>&1 || finish r18-pin
grep " $CAND\$" $L/b19-cand.sha256 | sha256sum -c >> $L/check-pins.log 2>&1 || finish candidate-pin
# 1. rung receipts, both ways
turn 1.0; step xbin
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio19-xbin --wait-secs 14400 --max-secs 900 --log $L/xbin-r19-r18.log --done $L/xbin-r19-r18.guard.done --result-json $L/xbin-r19-r18.guard.json -- $ENV HL_PB_CLI_BIN=$CAND HL_PB_CLI_BIN_OTHER=$B18 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_receipts_cross_verify_between_two_named_binaries --exact --ignored --nocapture
echo $? > $L/xbin-r19-r18.exit
[ "$(cat $L/xbin-r19-r18.exit)" = "0" ] || finish xbin
# 2. the real receipt, three fresh processes, its bytes hashed around each
python3 $T/tools/treehash.py $HATE $L/hate-tree-0.json > $L/hate-tree.log 2>&1 || finish hate-tree-0
turn 2.9; step verify-hate-unset
$G --class cpu --need-gib 2.9 --cap-gib 4.5 --label tio19-verify-hate --wait-secs 14400 --max-secs 1800 --log $L/verify-hate.log --done $L/verify-hate.guard.done --result-json $L/verify-hate.guard.json -- /usr/bin/env -u ZK60_MODELS RAYON_NUM_THREADS=8 $CAND verify --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-moderate-hate/1 --artifact $HATE --expect-statement $ID --min-bits 95
echo $? > $L/verify-hate.exit
python3 $T/tools/treehash.py $HATE $L/hate-tree-1.json >> $L/hate-tree.log 2>&1
[ "$(cat $L/verify-hate.exit)" = "0" ] || finish verify-hate
turn 2.9; step verify-hate-models
$G --class cpu --need-gib 2.9 --cap-gib 4.5 --label tio19-verify-hate-models --wait-secs 14400 --max-secs 1800 --log $L/verify-hate-models.log --done $L/verify-hate-models.guard.done --result-json $L/verify-hate-models.guard.json -- /usr/bin/env ZK60_MODELS=/home/victor/models RAYON_NUM_THREADS=8 $CAND verify --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-moderate-hate/1 --artifact $HATE --expect-statement $ID --min-bits 95
echo $? > $L/verify-hate-models.exit
python3 $T/tools/treehash.py $HATE $L/hate-tree-2.json >> $L/hate-tree.log 2>&1
[ "$(cat $L/verify-hate-models.exit)" = "0" ] || finish verify-hate-models
turn 2.9; step verify-hate-nomodels
$G --class cpu --need-gib 2.9 --cap-gib 4.5 --label tio19-verify-hate-nomodels --wait-secs 14400 --max-secs 1800 --log $L/verify-hate-nomodels.log --done $L/verify-hate-nomodels.guard.done --result-json $L/verify-hate-nomodels.guard.json -- /usr/bin/env ZK60_MODELS=$EQ/no-models-here RAYON_NUM_THREADS=8 $CAND verify --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-moderate-hate/1 --artifact $HATE --expect-statement $ID --min-bits 95
echo $? > $L/verify-hate-nomodels.exit
python3 $T/tools/treehash.py $HATE $L/hate-tree-3.json >> $L/hate-tree.log 2>&1
[ "$(cat $L/verify-hate-nomodels.exit)" != "0" ] || finish verify-hate-nomodels-accepted
grep -q "no-models-here" $L/verify-hate-nomodels.log || finish verify-hate-nomodels-reason
python3 -c "import json,sys; t=[json.load(open(f'$L/hate-tree-{i}.json'))['tree_sha256'] for i in range(4)]; print(t); sys.exit(0 if len(set(t))==1 else 1)" > $L/hate-tree-equal.log 2>&1 || finish hate-bytes-moved
# 3. the receipt bytes at real scale (fixed public entropy)
mkdir -p $EQ/single $EQ/batch
mkdir -m 700 -p $OWN $OWN/single-owner
step prepare
$G --class light --label tio19-bytes-prepare --max-secs 300 --log $LB/prepare.log --result-json $LB/prepare.guard.json -- /usr/bin/env PM_PROVER=shieldstral $VENV -B -c "import sys; sys.path.insert(0, sys.argv[1]); import batch_request as b; plan=b.proof_plans.category_work_plan(17, b.runtime.templates()); m=b.prepare_text('a5eq', 'Today I planted basil and watered the garden. The afternoon was quiet and sunny.', plan, sys.argv[2], sys.argv[3], reserved_context=b.records.screening_context()); print(len(m['jobs']), m['content_total'])" $A5 $JOB $EQ/batch
grep -qx "3 17" $LB/prepare.log || finish prepare
turn 1.5; step activations
$G --class cpu --need-gib 1.5 --cap-gib 3 --label tio19-bytes-act --wait-secs 14400 --max-secs 1800 --log $LB/act.log --done $LB/act.guard.done --result-json $LB/act.guard.json -- /usr/bin/env OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 $VENV -B $WRITER --request $JOB/activation-request.json --out $JOB/activations
echo $? > $LB/act.exit
[ "$(cat $LB/act.exit)" = "0" ] || finish activations
turn 10.4; step single-c0
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label tio19-bytes-single-c0 --wait-secs 14400 --max-secs 1800 --log $LB/single-c0.log --done $LB/single-c0.guard.done --result-json $LB/single-c0.guard.json -- bash $RF $EQ/ent/job0.bin -- /usr/bin/env -u ZK60_MODELS RAYON_NUM_THREADS=8 $CAND prove --export $EX --tables $TAB --policy shieldstral-1.0-3b-moderate-sexual/1 --content-file $JOB/content.ids --chunk 0 --seq-dir $JOB/activations/c0 --out $EQ/single/c0 --owner-dir $OWN/single-owner/c0 --label $LBL
echo $? > $LB/single-c0.exit
[ "$(cat $LB/single-c0.exit)" = "0" ] || finish single-c0
step compare
python3 $T/tools/compare19.py $EQ $OWN $R/r18/logs/eq/digests.json $LB/bytes.json > $LB/compare.log 2>&1
echo $? > $LB/compare.exit
[ "$(cat $LB/compare.exit)" = "0" ] || finish compare
python3 $T/tools/cleanup19.py $LB/cleanup.json > $LB/cleanup.log 2>&1 || finish cleanup
finish 0
