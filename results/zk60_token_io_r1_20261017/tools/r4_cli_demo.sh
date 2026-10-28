#!/bin/bash
# The token-I/O CLI on a trained Llama-3-8B T32 export (round 7: native R8 base; EXPORT selects the
# export, default the calibration lane's b7_T32; round 7's demo runs the fidelity lane's b7voc0_T32).
# layer-0 pre-check (before anything is built or proved) -> build the CLI -> prove (the owners'
# decommitments to the DEFAULT owner directory, keyed by the run's path, outside the repository; the
# path is read from prove's `proved` line) -> verify from a VERIFIER COPY of the export (public files
# only, hard links) with BOTH pins read from the APPROVAL RECORD (never from `profile` over the
# prover's files: review TR5-3) -> verify again (byte-for-byte re-check) -> owner and input-owner (each
# re-verifies the published statement against every segment first) -> the full suite.
# Each leaf guarded on its own; every step's exit code in <logs>/<TAG>-<label>.exit.
#
# Settings (environment):
#   EXPORT=DIR      the prover's export (default the calibration lane's llama3_8b_pg_rot1_b7_T32)
#   TAG=r7          names the binary copy, the run directory, the log labels and the done marker
#   SEQ=ho00        a calibration hold-out sequence of the export (seq_<ID>/), the default prompt
#   SEQ_DIR=DIR     a prover-private sequence directory instead (its manifest's token_ids, or PROMPT_IDS)
#   PROMPT_IDS=...  the prompt's ids (passed to prove as --prompt)
#   APPROVAL=FILE   the approval record holding the pins (default approvals/token_profile_approval_
#                   <export name>.json)
#   LOGS=DIR        where the logs go (default logs/ for a calibration SEQ)
#   BIN=FILE        use this built binary copy (no build step)
#   PROVE_NEED / PROVE_CAP / VERIFY_NEED / VERIFY_CAP   the guard's GiB for prove and for each
#                   verifying step (defaults 4.5 / 6.5 / 4 / 6, the T32 runs' measured peaks plus room;
#                   round 8 sets them from the T128 peaks)
#   NO_SUITE=1      skip the full suite at the end
#   WAIT_SECS=N     how long each guarded step may wait for the lock and budget (default 14400)
# A prompt that is not a calibration hold-out sequence (SEQ_DIR or PROMPT_IDS) is PROVER-PRIVATE: its
# logs (the pre-check names its tokens; input-owner's command line carries it) go to a 0700 directory
# under $HOME/zk60-artifacts/token-io/ by default, and a LOGS inside the repository is refused
# (review TR5-2 (d)).
# The layer-0 pre-check (tools/layer0_precheck.py over tools/layer0_refusals.json, from the fidelity
# lane's exhaustive vocabulary scan): on today's 8B b7 exports " ." (id 662) and "Tags" (id 16309)
# leave the int8 range at layer 0 (site V), so a prompt containing either is refused by name (exit 2),
# with the pointer to the fix (a layer-0 recalibrated export is coming). Its scope is the layer-0
# norm_a / Q / K / V / RoPE sites; layer-0 scores and later layers are not covered.
# A re-run with the same TAG and prompt needs the previous run directory moved first (prove refuses
# to overwrite it or its owner directory).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
D=$R/cli
E=${EXPORT:-/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b7_T32}
EN=$(basename $E)
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
TAG=${TAG:-r7}
SEQ=${SEQ:-ho00}
APPROVAL=${APPROVAL:-$R/approvals/token_profile_approval_$EN.json}
if [ -n "$SEQ_DIR" ] || [ -n "$PROMPT_IDS" ]; then
  PRIVATE=1
  NAME=$TAG-private
  L=${LOGS:-$HOME/zk60-artifacts/token-io/demo-logs-$TAG}
  case $(realpath -m $L) in /home/victor/IntelligenceRegulation/*) echo "refused: LOGS=$L is inside the repository; a prover-private prompt's logs stay outside it (review TR5-2)"; exit 1 ;; esac
  mkdir -p -m 700 $L
else
  PRIVATE=0
  NAME=$TAG-$SEQ
  L=${LOGS:-$R/logs}
  mkdir -p $L
fi
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
g() { # class label need cap max -- cmd...
  local cls=$1 lab=$TAG-$2 need=$3 cap=$4 max=$5; shift 6
  $G --class $cls --need-gib $need --cap-gib $cap --label tio-$lab --wait-secs ${WAIT_SECS:-14400} --max-secs $max --log $L/$lab.log --done $L/$lab.done --result-json $L/$lab.guard.json -- "$@"
  echo $? > $L/$lab.exit
}
ok() { [ "$(cat $L/$TAG-$1.exit)" = "0" ]; }
stop() { echo done > $L/${TAG}_cli_demo.done; exit 1; }
mkdir -p $D
# the prompt (prover-private input of `prove`)
if [ -n "$PROMPT_IDS" ]; then PROMPT=$PROMPT_IDS
elif [ -n "$SEQ_DIR" ]; then PROMPT=$(python3 -c "import json;print(','.join(str(x) for x in json.load(open('$SEQ_DIR/manifest.json'))['token_ids']))") || stop
else PROMPT=$(python3 -c "import json;print(','.join(str(x) for x in json.load(open('$E/seq_$SEQ/manifest.json'))['token_ids']))") || stop
fi
if [ -n "$SEQ_DIR" ]; then SEQ_FLAG="--seq-dir $SEQ_DIR"; else SEQ_FLAG="--seq $SEQ"; fi
if [ -n "$PROMPT_IDS" ]; then PROMPT_FLAG="--prompt $PROMPT_IDS"; else PROMPT_FLAG=; fi
# FIRST: the layer-0 pre-check, before anything is built or proved
python3 $R/tools/layer0_precheck.py check --export $E --emb $E/token_io --prompt $PROMPT > $L/$TAG-d0-precheck.log 2>&1
echo $? > $L/$TAG-d0-precheck.exit
cat $L/$TAG-d0-precheck.log
ok d0-precheck || stop
# the pins: from the approval record, never from the prover's files (review TR5-3)
PINS_LINE=$(python3 -c "
import json,sys
r=json.load(open('$APPROVAL'))
if r['export']!='$E': sys.exit('the approval record is for '+r['export']+', not $E')
print(r['pins']['expect_statement'], r['pins']['expect_token_profile'])") || stop
read ID TP <<< "$PINS_LINE"
echo "pins from $APPROVAL: expect-statement $ID, expect-token-profile $TP"
if [ -n "$BIN" ]; then
  # a binary already built and copied (its hash recorded beside it): no rebuild, so source edits made
  # while the demo runs never reach it
  B=$BIN
  sha256sum $B > $L/$TAG-binary.sha256
else
  g build d1-cli-build 3 5 1800 -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io
  ok d1-cli-build || stop
  cp $H/target/release/examples/zk60_token_io $D/zk60_token_io.$TAG.release.bin
  sha256sum $D/zk60_token_io.$TAG.release.bin > $D/binaries_$TAG.sha256
  B=$D/zk60_token_io.$TAG.release.bin
fi
# the verifier's copy of the export: every public entry hard-linked, no seq_*
V=$D/verifier-export-$EN
if [ ! -d $V ]; then
  mkdir -p $V
  for x in $E/*; do n=$(basename $x); case $n in seq_*) ;; *) cp -al $x $V/$n ;; esac; done
fi
RUN=$D/run-$EN-$NAME
PN=${PROVE_NEED:-4.5}; PC=${PROVE_CAP:-6.5}; VN=${VERIFY_NEED:-4}; VC=${VERIFY_CAP:-6}
g cpu d3-cli-prove $PN $PC 3600 -- $B prove --export $E --emb $E/token_io --head $E/token_io $SEQ_FLAG $PROMPT_FLAG --out $RUN
ok d3-cli-prove || stop
# the owner directory prove claimed (default: keyed by the run's canonical path)
OD=$(python3 -c "import json;l=[json.loads(x) for x in open('$L/$TAG-d3-cli-prove.log') if x.startswith('{\"event\":\"proved\"')];print(l[-1]['owner_dir'])") || stop
echo "owner directory: $OD"
PINS="--export $V --emb $V/token_io --head $V/token_io --artifact $RUN --expect-statement $ID --expect-token-profile $TP"
g cpu d4-cli-verify $VN $VC 3600 -- $B verify $PINS
g cpu d5-cli-recheck $VN $VC 3600 -- $B verify $PINS
g cpu d6-cli-owner $VN $VC 3600 -- $B owner $PINS --decommitment $OD/output.dec
g cpu d7-cli-input-owner $VN $VC 3600 -- $B input-owner $PINS --decommitment $OD/input.dec --prompt $PROMPT
if [ -z "$NO_SUITE" ]; then
  g cpu full-suite 6.5 8 2700 -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
fi
echo done > $L/${TAG}_cli_demo.done
