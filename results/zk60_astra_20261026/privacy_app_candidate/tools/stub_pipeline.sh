#!/bin/bash
# Proven Media, StubProver pipeline: ONE post through today's next-token CLI (TinyLlama T32),
# every heavy leaf through the project's resource guard, detached from the web server.
#
#   usage: stub_pipeline.sh JOB_DIR          (settings in JOB_DIR/job.env, written by the app)
#
# job.env holds paths and PUBLIC pins only (no content). MODE=prove runs
#   seqgen (prover-private activations) -> prove -> verify (public files only) -> owner (the
#   platform opens the sealed output; kept private) -> input-owner (the proof's hidden input is
#   this post);
# MODE=recheck runs verify -> input-owner again on an existing run (the "check this proof" button).
# Each step: logs/<step>.log (CLI JSON lines), <step>.guard.json, <step>.exit. Progress in
# step.current. The exit code lands in pipeline.done (written last, atomically). The coordinator
# pauses the queue by creating $HOLD_FILE; the script waits before each step, never mid-step.
# The post's text never appears on a command line: the CLI reads it from the 0600 prompt file.
set -u
JOB=$1
. "$JOB/job.env"
umask 077
L=$JOB/logs
mkdir -p -m 700 "$L"
echo $$ > "$JOB/pipeline.pid"
cat /proc/sys/kernel/random/boot_id > "$JOB/pipeline.boot_id" 2>/dev/null
G="python3 $GUARD run"

fin() {
  echo "done $(date +%s)" > "$JOB/step.current"
  echo "$1" > "$JOB/pipeline.done.tmp"
  mv "$JOB/pipeline.done.tmp" "$JOB/pipeline.done"
  exit 0
}
hold() {
  while [ -e "$HOLD_FILE" ]; do echo "held $(date +%s)" > "$JOB/step.current"; sleep 30; done
}
step() { # NAME -- CMD...: guarded; declarations from DECL_<NAME>="class need cap maxsecs"
  local n=$1; shift 2
  local var="DECL_$n"
  local cls need cap max
  read cls need cap max <<< "${!var}"
  hold
  echo "$n $(date +%s)" > "$JOB/step.current"
  $G --class "$cls" --need-gib "$need" --cap-gib "$cap" --label "pm-$n-$JOB_ID" --wait-secs "$WAIT_SECS" \
     --max-secs "$max" --log "$L/$n.log" --done "$L/$n.guard.done" --result-json "$L/$n.guard.json" \
     -- "$@" > "$L/$n.guard.out" 2>&1
  echo $? > "$L/$n.exit"
}
ok() { [ "$(cat "$L/$1.exit" 2>/dev/null)" = 0 ]; }

GOT=$(sha256sum "$BIN" | cut -c1-64)
if [ "$GOT" != "$BIN_SHA" ]; then echo "the prover binary is not the pinned build ($GOT)" > "$L/fatal.txt"; fin 10; fi
PINS="--export $VEXPORT --emb $VEXPORT --head $HEAD --artifact $RUN --expect-statement $PIN_STATEMENT --expect-token-profile $PIN_TOKEN_PROFILE"

if [ "$MODE" = prove ]; then
  step seqgen -- "$SYSPY" "$SEQGEN" --export "$EXPORT" --prompt-file "$PROMPT" --out "$SEQ"
  ok seqgen || { rm -rf "$SEQ"; fin 11; }
  step prove -- "$BIN" prove --export "$EXPORT" --emb "$EXPORT" --head "$HEAD" --seq-dir "$SEQ" \
       --prompt-file "$PROMPT" --out "$RUN" --owner-dir "$OWNER"
  # the hidden activations are re-creatable and no longer needed: do not keep them at rest
  rm -rf "$SEQ"
  ok prove || fin 12
fi
step verify -- "$BIN" verify $PINS
ok verify || fin 13
if [ "$MODE" = prove ]; then
  step owner -- "$BIN" owner $PINS --decommitment "$OWNER/output.dec" --token-out "$OWNER/next_token"
  ok owner || fin 14
fi
step inowner -- "$BIN" input-owner $PINS --decommitment "$OWNER/input.dec" --prompt-file "$PROMPT"
ok inowner || fin 15
fin 0
