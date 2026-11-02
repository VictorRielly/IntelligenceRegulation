#!/bin/bash
# D60 (2026-11-02): FRESH-PROCESS receipts through the production CLI (`zk60_trained_block stack-prove` /
# `stack-verify`, the path every registered run profile's receipts took), on the PUBLIC SYNTHETIC R13 loader
# fixture `r13-h24-wide` and its public sequence `seq_public` only. TEST RECEIPTS, NOT FOR PUBLICATION: D60
# requires the Python privacy gate on a D55 capture before any receipt for real content.
#   1. stack-prove --d55-workers 1  (the registered D55 profile of R13_RUNG_H24's run profile; L = 1, the
#      fixture's one layer)                                                          -> must exit 0
#   2. stack-verify --d55-workers 1, a NEW process, on a verifier copy of the export without seq_*  -> 0
#   3. stack-verify (the D12a verifier) on the D55 run directory                     -> must exit 1
#   4. stack-prove (D12a) of the same base; stack-verify --d55-workers 1 on it       -> must exit 1
#   5. stack-verify (D12a) on the D12a run directory                                 -> 0
# Receipts outside the repository (`/Users/victorrielly/zk60-artifacts/d60_20261102/cli/`); their file names,
# lengths and SHA-256 are copied into logs/cli/ (the statement directories' segments.json).
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a13712d1ade4dcee1
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/logs/cli
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
FX=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures/r13-h24-wide
A=/Users/victorrielly/zk60-artifacts/d60_20261102/cli
X=$R/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_trained_block
export ZK60_GUARD_POLL_SECS=0.05
mkdir -p $L
P=$L/prior-$(date +%Y%m%dT%H%M%S); for f in $L/c_*; do [ -e "$f" ] || continue; mkdir -p $P; mv "$f" $P/; done
[ -e "$A" ] && { echo "$A exists; the receipts go into a new directory"; exit 1; }
mkdir -p $A
printf 'TEST RECEIPTS, NOT FOR PUBLICATION. Proved by results/zk60_d60_20261102/cli_receipts.sh on the public synthetic R13 loader fixture r13-h24-wide and its public sequence; no real content. D60 requires the Python privacy gate on a D55 capture before any receipt for real content.\n' > $A/TEST_RECEIPTS_NOT_FOR_PUBLICATION.txt
step() { echo "== $1 $(date +%H:%M:%S)"; }

step build-example
$G --class build --need-gib 4 --cap-gib 10 --label d60-cli-build --wait-secs 7200 --max-secs 3600 --log $L/c_build.log --done $L/c_build.done -- \
  cargo build --release --offline --locked --features gpu-metal --manifest-path $H --example zk60_trained_block || { grep -E -A12 '^error' $L/c_build.log | head -60; exit 1; }
shasum -a 256 $X | tee $L/c_binary.sha256

# the verifier's export: the fixture's PUBLIC files only (stack-verify refuses an export holding seq_*)
mkdir -p $A/verifier-export
cp $FX/profile.json $A/verifier-export/
cp -R $FX/layer_00 $A/verifier-export/

run_x() { # <stem> <expect-exit> <args...>
  local stem=$1 want=$2; shift 2
  $G --class cpu --need-gib 4 --cap-gib 20 --label d60-cli-$stem --wait-secs 7200 --max-secs 1800 --log $L/c_$stem.log --done $L/c_$stem.done -- \
    env HL_R13_LOADER_FIXTURES=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures $X "$@"
  local got=$(cat $L/c_$stem.done 2>/dev/null | head -1)
  echo "$stem: exit $got (want $want)"
  grep -h '"event"' $L/c_$stem.log | cut -c1-400 | tail -6
  [ "$got" = "$want" ] || { echo "STEP $stem EXITED $got, NOT $want"; exit 1; }
}

step d55-prove
run_x d55_prove 0 stack-prove --export $FX --seq public --out $A/d55-run --d55-workers 1
ID=$(grep -h -o '"statement_identity":"[0-9a-f]*"' $L/c_d55_prove.log | head -1 | cut -d'"' -f4)
echo "statement identity $ID"
[ -n "$ID" ] || { echo "NO STATEMENT IDENTITY"; exit 1; }
grep -q '"event":"d55"' $L/c_d55_prove.log || { echo "THE PROVER DID NOT TAKE THE D55 PATH"; exit 1; }
ls -la $A/d55-run $A/d55-run.unverified-statement | tee $L/c_d55_dir.txt

step d55-verify-fresh
run_x d55_verify 0 stack-verify --export $A/verifier-export --artifact $A/d55-run --expect-statement $ID --d55-workers 1
grep -q '"event":"statement-published"' $L/c_d55_verify.log || { echo "THE D55 VERIFIER DID NOT PUBLISH THE STATEMENT"; exit 1; }
cp $A/d55-run/statement/segments.json $L/c_d55_segments.json
cp $A/d55-run/statement/statement.json $L/c_d55_statement.json

step d12a-verifier-on-d55
run_x d12a_on_d55 1 stack-verify --export $A/verifier-export --artifact $A/d55-run --expect-statement $ID

step d12a-prove
run_x d12a_prove 0 stack-prove --export $FX --seq public --out $A/d12a-run
ID2=$(grep -h -o '"statement_identity":"[0-9a-f]*"' $L/c_d12a_prove.log | head -1 | cut -d'"' -f4)

step d55-verifier-on-d12a
run_x d55_on_d12a 1 stack-verify --export $A/verifier-export --artifact $A/d12a-run --expect-statement $ID2 --d55-workers 1

step d12a-verify-fresh
run_x d12a_verify 0 stack-verify --export $A/verifier-export --artifact $A/d12a-run --expect-statement $ID2
cp $A/d12a-run/statement/segments.json $L/c_d12a_segments.json

step done
