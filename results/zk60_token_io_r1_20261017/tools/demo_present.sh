#!/bin/bash
# PRESENTER DEMO (token-I/O lane, round 10): ONE private next-token proof, narrated in plain
# language for a non-specialist audience.
#
#   usage: tools/demo_present.sh [8b-t32 | tinyllama | 8b-t128]        (default: 8b-t32)
#
#   8b-t32     Llama-3-8B, 32-token prompt (export llama3_8b_pg_rot1_b7voc0_T32);   538 s of work
#              in the round-11 dry run [MEASURED: prove 296 s with loading, verify 82 s]
#   tinyllama  TinyLlama-1.1B, 32-token prompt (export pg_rot1_b4_T32_cal128);      the fast option:
#              130-132 s of work in the two round-10 dry runs [MEASURED]
#   8b-t128    Llama-3-8B, 128-token prompt (export llama3_8b_dg_rot1_voc0_T128, the per-layer
#              "dg" export: the best 8B fidelity so far, same speed); 839 s of work in the
#              round-11 dry run [MEASURED: prove 569 s with loading, verify 88 s; peak 7.99 GiB]
# Plus any time the guard waits for the machine (a busy box made the dry runs wait 9-23 min).
#
# Steps: safety pre-check -> PROVE -> VERIFY -> the prompt owner OPENS THE ANSWER -> the prompt
# owner CONFIRMS THE PROMPT. The binary is the frozen round-11 CPU build (sha256 checked first;
# cli/binaries_r11.sha256, build note cli/zk60_token_io.r11.BUILD.txt);
# no prover code is changed by this script. The prompt is the export's calibration hold-out
# sequence (SEQ, default ho00), written to a 0600 prompt file; the pins come from the approval
# record in approvals/, never from the prover's files (review TR5-3).
#
# Where things go (all OUTSIDE the repository):
#   ~/zk60-owner-private/token-io/demo-present/<TAG>/   0700: transcript.txt, the prompt file,
#                                                       every step's log, the exit code
#   ~/zk60-artifacts/token-io/demo-present/run-<TAG>/   the proof (public)
#   ~/zk60-owner-private/token-io/<run>-<key>.owner-private/   the owners' decommitments and the
#                                                       opened answer (prove's default, 0700)
# The demo DETACHES itself (setsid nohup) and this window follows its transcript; if the window
# closes, the demo carries on (tail -f the transcript to watch again). Every heavy step runs
# through the resource guard (scripts/zk60_resource_guard.py) and waits for the machine to be
# free; for a live showing, run it on a quiet box.
#
# Settings: TAG (default <model>-<UTC time>), SEQ (default ho00), WAIT_SECS (guard wait per
# step, default 3600).
set -u
MODEL=${1:-8b-t32}
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
BIN=$R/cli/zk60_token_io.r11.release.bin
BIN_SHA=0c9f247c0f91162177f8ed90285f8664cc4dd36ebd8934dc650804bafe5c2c6b
X=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports
case "$MODEL" in
  8b-t32)
    E=$X/llama3_8b_pg_rot1_b7voc0_T32; EMB=$E/token_io; HEAD=$E/token_io; TOK=llama3
    NAME="Llama-3-8B (8 billion parameters)"; T=32; PN=4.5; PC=6.5; VN=4; VC=5.5
    BASE="about 1.5 s (a tuned CPU engine with 8-bit weights; measured 2026-10-19)" ;;
  8b-t128)
    E=$X/llama3_8b_dg_rot1_voc0_T128; EMB=$E/token_io; HEAD=$E/token_io; TOK=llama3
    NAME="Llama-3-8B (8 billion parameters)"; T=128; PN=8.5; PC=10; VN=4.5; VC=6   # prove: r8 peak 7.97 GiB + margin
    BASE="about 5.6 s (a tuned CPU engine with 8-bit weights; measured 2026-10-19)" ;;
  tinyllama)
    E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128
    EMB=$E; HEAD=$R/r2_inputs; TOK=tinyllama
    NAME="TinyLlama-1.1B (1.1 billion parameters)"; T=32; PN=3.5; PC=5; VN=3; VC=4.5
    BASE="" ;;
  *) echo "usage: $0 [8b-t32 | tinyllama | 8b-t128]"; exit 2 ;;
esac
EN=$(basename $E)
SEQ=${SEQ:-ho00}
TAG=${TAG:-$MODEL-$(date -u +%Y%m%dT%H%M%SZ)}
PRIV=$HOME/zk60-owner-private/token-io/demo-present/$TAG
PUB=$HOME/zk60-artifacts/token-io/demo-present
TR=$PRIV/transcript.txt

# ---- the presenter's window: start the detached demo, follow its transcript
if [ -z "${DEMO_PRESENT_CHILD:-}" ]; then
  umask 077
  mkdir -p -m 700 $HOME/zk60-owner-private $HOME/zk60-owner-private/token-io $HOME/zk60-owner-private/token-io/demo-present
  chmod 700 $HOME/zk60-owner-private $HOME/zk60-owner-private/token-io $HOME/zk60-owner-private/token-io/demo-present
  mkdir -m 700 $PRIV 2>/dev/null || { echo "refused: $PRIV exists; choose another TAG"; exit 1; }
  setsid nohup /usr/bin/env DEMO_PRESENT_CHILD=1 TAG=$TAG SEQ=$SEQ WAIT_SECS=${WAIT_SECS:-3600} bash "$(readlink -f "$0")" $MODEL > $TR 2>&1 < /dev/null &
  for i in $(seq 1 100); do [ -s $PRIV/child.pid ] && break; sleep 0.1; done
  [ -s $PRIV/child.pid ] || { echo "the demo did not start; see $TR"; exit 1; }
  echo "(the demo runs detached; if this window closes it carries on: tail -f $TR)"
  tail -n +1 -f --pid=$(cat $PRIV/child.pid) $TR
  exit $(cat $PRIV/exit 2>/dev/null || echo 1)
fi

# ---- the detached demo
echo $$ > $PRIV/child.pid
umask 077
L=$PRIV/logs
mkdir -p -m 700 $L
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
say() { echo "$@"; }
fin() { echo $1 > $PRIV/exit; echo $1 > $PRIV/demo.done; say ""; say "transcript: $TR"; exit $1; }
fail() { say ""; say "  !! STOPPED: $1"; say "     details: $2"; fin 1; }
ev() { # FILE EVENT KEY: KEY of the last {"event":"EVENT"} line of FILE
  python3 -c "import json,sys
l=[json.loads(x) for x in open(sys.argv[1]) if x.startswith('{\"event\":\"'+sys.argv[2]+'\"')]
print(l[-1].get(sys.argv[3], '') if l else '')" "$1" "$2" "$3" 2>/dev/null
}
waited() { python3 -c "import json,sys;print(int(json.load(open(sys.argv[1])).get('waited_s') or 0))" "$1" 2>/dev/null || echo 0; }
step() { # LABEL CLASS NEED CAP MAXSECS -- CMD...: guarded; CLI output in logs/LABEL.log
  local lab=$1 cls=$2 need=$3 cap=$4 max=$5; shift 6
  local t=$(date +%s)
  $G --class $cls --need-gib $need --cap-gib $cap --label tio-demo-$lab --wait-secs $WAIT_SECS --max-secs $max --log $L/$lab.log --done $L/$lab.guard.done --result-json $L/$lab.guard.json -- "$@" > $L/$lab.guard.out 2>&1
  echo $? > $L/$lab.exit
  local w=$(waited $L/$lab.guard.json)
  STEP_WALL=$(( $(date +%s) - t ))
  WAITED=$(( WAITED + w ))
  [ "$w" -gt 5 ] && say "          (waited $w s for the machine to be free first)"
  return 0
}
refusal() { grep -h 'refused\|REFUSED' "$1" 2>/dev/null | tail -1 | cut -c1-300; }
T0=$(date +%s)
WAITED=0

say "=============================================================================="
say " A PRIVATE AI ANSWER, PROVED"
say " $NAME, one ${T}-token prompt"
say "=============================================================================="
say " What you will see: a computer (the PROVER) runs a public AI model on a PRIVATE"
say " prompt and produces a proof that the model's next word (computed by its exact integer"
say " version) really came from that prompt and that model. A second party (the VERIFIER)"
say " checks the proof without ever being given the prompt or the answer. Only the prompt's"
say " owner can open the answer."
say ""
say " machine:  this laptop's CPU ($(lscpu 2>/dev/null | sed -n 's/^Model name: *//p' | head -1)); no GPU is used"
GOT=$(sha256sum $BIN | cut -c1-64)
[ "$GOT" = "$BIN_SHA" ] || fail "the proving software is not the frozen round-11 build" "$BIN has sha256 $GOT, expected $BIN_SHA"
say " software: zk60_token_io, frozen round-11 CPU build (sha256 ${BIN_SHA:0:16}..., checked)"
APPROVAL=$R/approvals/token_profile_approval_$EN.json
PINS_LINE=$(python3 -c "
import json,sys
r=json.load(open('$APPROVAL'))
if r['export']!='$E': sys.exit('the approval record is for '+r['export'])
print(r['pins']['expect_statement'], r['pins']['expect_token_profile'])" 2>&1) || fail "no approval record for this model" "$PINS_LINE"
read ID TP <<< "$PINS_LINE"
say " model:    the approved public model files, fingerprint ${ID:0:16}... (approvals/$(basename $APPROVAL))"
say ""

# the prompt owner's prompt, in a 0600 file (never on a command line)
[ -f $E/seq_$SEQ/manifest.json ] || fail "no prompt $SEQ for this model" "$E/seq_$SEQ/manifest.json missing"
PF=$PRIV/prompt-$SEQ
python3 -c "
import json,os,sys
ids=json.load(open(sys.argv[1]))['token_ids']
fd=os.open(sys.argv[2], os.O_WRONLY|os.O_CREAT|os.O_EXCL, 0o600)
os.write(fd, (','.join(str(x) for x in ids)+'\n').encode()); os.close(fd)" $E/seq_$SEQ/manifest.json $PF || fail "could not write the prompt file" "$PF"
PTEXT=$(python3 $R/tools/demo_decode.py $TOK --ids-file $PF | python3 -c "import json,sys;print(' '.join(json.load(sys.stdin)['text'].split()))")
say "[prompt owner] The private prompt (${T} tokens; only the owner sees this):"
say "    \"$PTEXT\""
say "    (a held-out test text, $SEQ, never used to calibrate the model)"
say ""

# step 1: the safety pre-check
say "step 1/5  SAFETY PRE-CHECK: is any word of the prompt known to overflow the integer model?"
python3 $R/tools/layer0_precheck.py check --export $E --emb $EMB --prompt-file $PF > $L/precheck.log 2>&1
RC=$?
ST=$(ev $L/precheck.log layer0-precheck status)
if [ $RC = 2 ]; then fail "the prompt contains a word this model's integer version cannot handle at layer 0" "$(grep -h 'refused before proving' $L/precheck.log | head -1)"
elif [ $RC != 0 ]; then fail "the pre-check did not run" "$L/precheck.log"
elif [ "$ST" = clear ]; then say "          clear: no word of the prompt is on the list of known overflows"
else say "          no overflow scan is recorded for this exact model; skipped (the proof refuses such a prompt by itself)"
fi
say ""

# step 2: prove
RUN=$PUB/run-$TAG
mkdir -p $PUB
say "step 2/5  PROVE: the prover is proving the ${T}-token prompt without revealing it..."
say "          (it runs every layer of the model on the hidden prompt, seals each step"
say "           cryptographically, and checks its own work before writing anything)"
step prove cpu $PN $PC 3600 -- $BIN prove --export $E --emb $EMB --head $HEAD --seq $SEQ --prompt-file $PF --out $RUN
[ "$(cat $L/prove.exit)" = 0 ] || fail "the prover refused or failed (nothing was published)" "$(refusal $L/prove.log) ($L/prove.log)"
PROVE_S=$(ev $L/prove.log proved prove_seconds); TOTAL_S=$(ev $L/prove.log proved total_seconds)
BYTES=$(ev $L/prove.log proved receipt_bytes); SEGS=$(ev $L/prove.log proved segments)
FLOOR=$(ev $L/prove.log proved whole_run_floor_bits); OD=$(ev $L/prove.log proved owner_dir)
MB=$(python3 -c "print(f'{$BYTES/1e6:.1f}')")
say "          done: proved in $(printf %.0f $PROVE_S) s ($(printf %.0f $TOTAL_S) s with loading the model)"
say "          proof size: $MB MB, in $SEGS sealed parts; security level $FLOOR bits (the verifier requires 95)"
say ""

# step 3: verify, from a copy of the PUBLIC files only
V=$PUB/verifier-export-$EN
if [ ! -d $V ]; then
  mkdir -p $V
  for x in $E/*; do n=$(basename $x); case $n in seq_*) ;; *) cp -al $x $V/$n ;; esac; done
fi
if [ "$TOK" = tinyllama ]; then VEMB=$V; VHEAD=$HEAD; else VEMB=$V/token_io; VHEAD=$V/token_io; fi
PINS="--export $V --emb $VEMB --head $VHEAD --artifact $RUN --expect-statement $ID --expect-token-profile $TP"
say "step 3/5  VERIFY: a separate verifier, holding only the public model files and the proof,"
say "          checks every sealed step..."
step verify cpu $VN $VC 3600 -- $BIN verify $PINS
[ "$(cat $L/verify.exit)" = 0 ] || fail "the verifier REJECTED the proof" "$(refusal $L/verify.log) ($L/verify.log)"
VERIFY_S=$(ev $L/verify.log verified verify_seconds)
say "          the verifier checked the proof in $(printf %.0f $VERIFY_S) s; it was never given the prompt or the answer (*)"
say ""

# step 4: the prompt owner opens the answer
say "step 4/5  OPEN THE ANSWER: the prompt owner, holding the private opening file the prover"
say "          handed only to them, re-checks the proof and opens the answer..."
step owner cpu $VN $VC 3600 -- $BIN owner $PINS --decommitment $OD/output.dec --token-out $OD/next_token
[ "$(cat $L/owner.exit)" = 0 ] || fail "the answer could not be opened" "$(refusal $L/owner.log) ($L/owner.log)"
ANS=$(cat $OD/next_token)
# review TR7-3: the id is read from the owner's 0600 token file, never put on a command line
WORD=$(python3 $R/tools/demo_decode.py $TOK --id-file $OD/next_token | python3 -c "import json,sys;print(json.dumps(json.load(sys.stdin)['text']))")
say "          the prompt owner opens the answer: token $ANS ($WORD)"
say "          so the integer model's next word after the prompt is $WORD"
say ""

# step 5: the prompt owner confirms the proof used their prompt
say "step 5/5  CONFIRM THE PROMPT: the prompt owner checks the proof was made from their prompt..."
step inowner cpu $VN $VC 3600 -- $BIN input-owner $PINS --decommitment $OD/input.dec --prompt-file $PF
[ "$(cat $L/inowner.exit)" = 0 ] || fail "the proof does NOT match the owner's prompt" "$(refusal $L/inowner.log) ($L/inowner.log)"
say "          the prompt owner confirms the proof used their prompt"
say ""

say "------------------------------------------------------------------------------"
say " SUMMARY  ($NAME, ${T}-token prompt, this laptop's CPU)"
say "   proving:              $(printf %.0f $PROVE_S) s"
[ -n "$BASE" ] && say "   for scale:            ordinary (unproved) inference of a ${T}-token prompt: $BASE"
say "   proof size:           $MB MB"
say "   verifying:            $(printf %.0f $VERIFY_S) s"
say "   answer (owner only):  $WORD"
ALL=$(( $(date +%s) - T0 ))
say "   all five steps:       $(( ALL - WAITED )) s of work ($ALL s wall clock, $WAITED s of it waiting for the machine to be free)"
say "------------------------------------------------------------------------------"
say " (*) and the proof is designed so the verifier learns nothing about them. The formal privacy"
say "     acceptance so far (decision D33) covers one artifact: the TinyLlama block stack at"
say "     calibration pg_rot1, built from tree R7. This model, this calibration, this build and"
say "     the next-word stages are still under review. See DEMO_PRESENTER.md."
fin 0
