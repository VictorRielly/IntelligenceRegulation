#!/bin/bash
# The token-I/O CLI on the trained Llama-3-8B b7 T32 export (round 5: review round 4's fixes).
# build the CLI -> `profile` on the calibration lane's APPROVED export + tables (the token-profile pin)
# -> prove (prover-private seq_ho00; the owners' decommitments to the DEFAULT owner directory under
# $HOME/zk60-artifacts/token-io/, outside the repository) -> verify from a VERIFIER COPY of the export
# (public files only, hard links) with BOTH pins -> verify again (byte-for-byte re-check) -> owner and
# input-owner (each re-verifies the published statement against every segment first) -> the full suite.
# Each leaf guarded on its own; every step's exit code in logs/<label>.exit.
# FIRST, before anything is built or proved: the layer-0 prompt pre-check (tools/layer0_precheck.py over
# tools/layer0_refusals.json, recorded from the fidelity lane's exhaustive vocabulary scan): on today's
# 8B b7 exports " ." (id 662) and "Tags" (id 16309) leave the int8 range at layer 0 (site V), so a prompt
# containing either is refused by name here (exit 2 in logs/d0-precheck.exit), with the pointer to the fix
# (a layer-0 recalibrated export is coming). Prompt: SEQ=<ID> (the export's seq_<ID>/, default ho00) or
# PROMPT_IDS=id,id,... (passed to prove as --prompt). LOGS=<dir> redirects the logs (default logs/).
# A re-run with the same SEQ needs the previous run directory and owner directory moved first (prove
# refuses to overwrite either).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=${LOGS:-$R/logs}
D=$R/cli
E=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b7_T32
SEQ=${SEQ:-ho00}
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
g() { # class label need cap max -- cmd...
  local cls=$1 lab=$2 need=$3 cap=$4 max=$5; shift 6
  $G --class $cls --need-gib $need --cap-gib $cap --label tio-$lab --wait-secs 14400 --max-secs $max --log $L/$lab.log --done $L/$lab.done --result-json $L/$lab.guard.json -- "$@"
  echo $? > $L/$lab.exit
}
ok() { [ "$(cat $L/$1.exit)" = "0" ]; }
stop() { echo done > $L/r5_cli_demo.done; exit 1; }
mkdir -p $D $L
if [ -n "$PROMPT_IDS" ]; then PROMPT=$PROMPT_IDS; PROMPT_FLAG="--prompt $PROMPT_IDS"
else PROMPT=$(python3 -c "import json;print(','.join(str(x) for x in json.load(open('$E/seq_$SEQ/manifest.json'))['token_ids']))") || stop; PROMPT_FLAG=; fi
python3 $R/tools/layer0_precheck.py check --export $E --emb $E/token_io --prompt $PROMPT > $L/d0-precheck.log 2>&1
echo $? > $L/d0-precheck.exit
cat $L/d0-precheck.log
ok d0-precheck || stop
g build d1-cli-build 3 5 1800 -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io
ok d1-cli-build || stop
cp $H/target/release/examples/zk60_token_io $D/zk60_token_io.r5.release.bin
sha256sum $D/zk60_token_io.r5.release.bin > $D/binaries_r5.sha256
B=$D/zk60_token_io.r5.release.bin
# the verifier's copy of the export: every public entry hard-linked, no seq_*
V=$D/verifier-export-llama3_8b_pg_rot1_b7_T32
if [ ! -d $V ]; then
  mkdir -p $V
  for x in $E/*; do n=$(basename $x); case $n in seq_*) ;; *) cp -al $x $V/$n ;; esac; done
fi
# the pins: the trained identity the R3 harness derived independently, and the token profile of the
# calibration lane's approved export + tables (printed by `profile`)
ID=$(sed -n 's/^trained_statement_identity //p' $R/runs/r3/trained-ho00/statement.txt)
g light d2-cli-profile 3.5 5 900 -- $B profile --export $E --emb $E/token_io --head $E/token_io
ok d2-cli-profile || stop
TP=$(python3 -c "import json,sys;l=[json.loads(x) for x in open('$L/d2-cli-profile.log') if x.startswith('{\"event\":\"profile\"')];assert l and l[-1]['trained_statement_identity']=='$ID';print(l[-1]['token_profile_digest'])") || stop
echo "$TP" > $D/token_profile_pin_b7_T32.txt
RUN=$D/run-b7_T32-$SEQ-r5
OD=$HOME/zk60-artifacts/token-io/run-b7_T32-$SEQ-r5.owner-private
g cpu d3-cli-prove 4.5 6.5 1800 -- $B prove --export $E --emb $E/token_io --head $E/token_io --seq $SEQ $PROMPT_FLAG --out $RUN
ok d3-cli-prove || stop
PINS="--export $V --emb $V/token_io --head $V/token_io --artifact $RUN --expect-statement $ID --expect-token-profile $TP"
g cpu d4-cli-verify 4 6 1800 -- $B verify $PINS
g cpu d5-cli-recheck 4 6 1800 -- $B verify $PINS
g cpu d6-cli-owner 4 6 1800 -- $B owner $PINS --decommitment $OD/output.dec
g cpu d7-cli-input-owner 4 6 1800 -- $B input-owner $PINS --decommitment $OD/input.dec --prompt $PROMPT
g cpu s7-suite 6.5 8 2700 -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo done > $L/r5_cli_demo.done
