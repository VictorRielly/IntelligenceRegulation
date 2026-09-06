#!/bin/bash
# [ZK60-CL1] The lane's floors: both builds, the crate tests, the four frozen
# byte gates on BOTH binaries, the same four with the HIDING commitment's
# chunking FORCED (HL_ZK_CHUNK=1) so the frozen fixtures exercise the new
# code, and the CL1 GPU oracle suite including its negative control.
#
# [ZK60 round-7 review] Evidence the script itself now records or checks:
#   * SOURCE IDENTITY: git HEAD and the count of dirty tracked files;
#   * BINARY IDENTITY: sha256 + size of both binaries, after the builds;
#   * the oracle suite runs UNCAPTURED (--nocapture, one thread) into a
#     retained log, and its machine-readable ZK60_CL4_SUMMARY line is PARSED:
#     executed_cases must reach a floor and gpu_enabled must be true;
#   * the MISSING-FEATURE refusal: on the CPU target (no gpu-cuda) the same
#     test file must FAIL under HL_GPU_REQUIRED=1 and must report zero cases
#     without it — a build that compiles the device tests away cannot pass as
#     a GPU gate;
#   * every gate's full prover log is RETAINED in the scratch dir (only the
#     proof bytes are deleted), and its PROOF sha256 line is echoed here.
# Usage: cl1_floors.sh <scratch-dir>
set -u
R=/home/victor/wt-zk60-cl1
SP="${1:?scratchpad dir required}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
# The oracle suite's executed-case floor: `check()` cases + the review tests
# (28 at the time of writing; a lower count means cases were SKIPPED).
ORACLE_MIN_CASES=20

mkdir -p "$SP"
CPU=$R/hashline/target/release/hashline
GPU=$R/hashline/target-gpu/release/hashline
fail=0
say () { echo; echo "=== $* ==="; date '+%F %T'; }

say "source identity"
echo "HEAD      $(git --no-pager -C $R rev-parse HEAD)"
echo "branch    $(git --no-pager -C $R rev-parse --abbrev-ref HEAD)"
echo "dirty     $(git --no-pager -C $R status --porcelain --untracked-files=no | wc -l) tracked file(s) modified"
# [round-7 review] HEAD plus a dirty count cannot identify dirty build inputs;
# the content hash of the uncommitted delta under hashline/ can. On a clean
# checkout this is the hash of the empty diff (e3b0c442..).
echo "dirty-delta sha256 (hashline/)  $(git --no-pager -C $R diff HEAD -- hashline | sha256sum | cut -d' ' -f1)"
echo "scratch   $SP (per-gate prover logs are retained here)"

say "CPU build"
flock /tmp/zk-build.lock cargo build --release --manifest-path $R/hashline/Cargo.toml || { echo "FAILURE: CPU build"; exit 1; }

say "GPU build (feature gpu-cuda)"
CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD \
  CARGO_TARGET_DIR=$R/hashline/target-gpu \
  flock /tmp/zk-build.lock cargo build --release --features gpu-cuda --manifest-path $R/hashline/Cargo.toml \
  || { echo "FAILURE: GPU build"; exit 1; }

say "binary identity"
echo "CPU binary  $(sha256sum "$CPU" | cut -d' ' -f1)  $(stat -c %s "$CPU") B  $CPU"
echo "GPU binary  $(sha256sum "$GPU" | cut -d' ' -f1)  $(stat -c %s "$GPU") B  $GPU"

say "cargo test --release (CPU, --test-threads=2)"
# record EVERY binary's result line: `tail` hid the lib suite's count on the
# first run, which left the log unable to show what the exit code had checked.
# --test-threads=2 is Codex's own CPU baseline (ZK60_CLAUDE_QUEUE.md). At the
# default parallelism three Codex `verifier_hardening_tests` race the
# pcs_compact lib tests, which `configure()` the PROCESS-GLOBAL compact PCS;
# that is a Codex-owned test hazard, recorded in the lane report, not a lane
# defect — and not something these floors should silently mask either, so it
# is named here.
flock /tmp/zk-build.lock cargo test --release --manifest-path $R/hashline/Cargo.toml -- --test-threads=2 2>&1 | grep -E '^test result:|^error|panicked'
[ "${PIPESTATUS[0]}" = 0 ] || { echo "FAILURE: cargo test"; fail=1; }

say "CL1 GPU oracle suite (chunked hiding commit vs the CPU, + negative control) — uncaptured, one thread"
ORACLE_LOG=$SP/oracle_gpu.out
CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu HL_GPU=1 HL_GPU_REQUIRED=1 \
  flock /tmp/zk-build.lock cargo test --release --features gpu-cuda --manifest-path $R/hashline/Cargo.toml --test zk60_gpu_commit -- --test-threads=1 --nocapture > "$ORACLE_LOG" 2>&1
orc=$?
grep -E '^test result:|panicked|FAILED' "$ORACLE_LOG" | head -5
SUMMARY=$(grep 'ZK60_CL4_SUMMARY' "$ORACLE_LOG" | tail -1 | sed 's/^.*ZK60_CL4_SUMMARY //')
echo "oracle summary: ${SUMMARY:-<none emitted>}"
if [ "$orc" != 0 ]; then echo "FAILURE: CL1 GPU oracle suite exited $orc"; fail=1; fi
# [round-7 review, Codex] the first version of this parser put `\"` escapes
# inside f-string expressions, which Python 3.10 refuses (SyntaxError:
# f-string expression part cannot include a backslash) — so the gate could
# not have passed. Values are bound to plain names first now, and the parser
# is exercised on its own by `python3 -c` below before any oracle run.
ORACLE_PARSE='
import json, sys
s = json.loads(sys.argv[1]); floor = int(sys.argv[2])
cases = s.get("executed_cases"); device = s.get("device")
ok = s.get("gpu_enabled") is True and s.get("gpu_required") is True and isinstance(cases, int) and cases >= floor
print("oracle cases executed: %s (floor %d); device: %s" % (cases, floor, device))
sys.exit(0 if ok else 1)
'
SELFTEST='{"executed_cases":99,"gpu_enabled":true,"gpu_required":true,"device":"self-test — non-ASCII on purpose"}'
# the self-test goes through the SAME expansion the real check uses
if ! python3 -c "$ORACLE_PARSE" "${SELFTEST:-"{}"}" 1 >/dev/null; then
  echo "FAILURE: the embedded oracle-summary parser does not run on this Python (or the expansion mangles it)"; fail=1
fi
# `${SUMMARY:-{}}` is NOT a JSON default in bash: the expansion ends at the
# first `}`, so a literal `}` was appended to a perfectly good summary and
# the decoder saw "extra data" — the gate went RED on a 49-case green run
# (results/cl_round7_floors_attempt3_bracebug.log). Quote the default.
if ! python3 -c "$ORACLE_PARSE" "${SUMMARY:-"{}"}" "$ORACLE_MIN_CASES"; then
  echo "FAILURE: the oracle suite did not prove >= $ORACLE_MIN_CASES executed cases on an enabled device"; fail=1
fi

say "missing-feature refusal (CPU target, no gpu-cuda): HL_GPU_REQUIRED=1 must FAIL"
NOFEAT_LOG=$SP/oracle_nofeature.out
HL_GPU_REQUIRED=1 flock /tmp/zk-build.lock cargo test --release --manifest-path $R/hashline/Cargo.toml --test zk60_gpu_commit -- --nocapture > "$NOFEAT_LOG" 2>&1
nrc=$?
if [ "$nrc" = 0 ]; then
  echo "FAILURE: a build WITHOUT gpu-cuda passed under HL_GPU_REQUIRED=1 (vacuous gate)"; fail=1
elif grep -q 'built WITHOUT --features gpu-cuda' "$NOFEAT_LOG"; then
  echo "refused as required (exit $nrc): $(grep -o 'HL_GPU_REQUIRED=1 but this test binary was built WITHOUT --features gpu-cuda' "$NOFEAT_LOG" | head -1)"
else
  echo "FAILURE: the no-feature run failed for an unexpected reason (exit $nrc); see $NOFEAT_LOG"; fail=1
fi
say "missing-feature status (CPU target, no gpu-cuda): without the requirement it must report ZERO cases, not success as evidence"
flock /tmp/zk-build.lock cargo test --release --manifest-path $R/hashline/Cargo.toml --test zk60_gpu_commit -- --nocapture > "$NOFEAT_LOG.plain" 2>&1
prc=$?
PLAIN=$(grep 'ZK60_CL4_SUMMARY' "$NOFEAT_LOG.plain" | tail -1 | sed 's/^.*ZK60_CL4_SUMMARY //')
echo "no-feature summary (exit $prc): ${PLAIN:-<none emitted>}"
if [ "$prc" != 0 ] || ! echo "$PLAIN" | grep -q '"executed_cases":0,"gpu_enabled":false'; then
  echo "FAILURE: the no-feature run must pass AND report executed_cases 0 / gpu_enabled false"; fail=1
fi

# [ZK60-CL4 review] gate <name> <ref-sha256-FULL> <ref-bytes> <binary> <label> <args...>
#
# The first version compared `cut -c1-16` of the digest and ignored the proving
# subprocess's exit code entirely, so a truncated match or a crashed run that
# still left a file behind could have passed. It now checks, for every gate:
#   * the proving subprocess's EXIT CODE
#   * the verifier's ACCEPT line
#   * device execution (`gpu: ON`) whenever the label is a GPU one
#   * the FULL SHA-256 and the exact byte length
#   * a freshly produced artifact (the output is removed before the run)
# [round-7 review] and the prover's own PROOF sha256 line is echoed, the log
# is RETAINED (only the proof bytes are deleted).
CASES=0
gate () {
  local name=$1 ref=$2 refb=$3 bin=$4 label=$5; shift 5
  local out=$SP/$label-$name.proof
  local log=$SP/$label-$name.out
  say "GATE $name [$label]"
  rm -f "$out"
  case "$label" in
    gpu)         HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" > "$log" 2>&1 ;;
    gpu-zkchunk) HL_GPU=1 HL_ZK_CHUNK=1 LD_LIBRARY_PATH=$CUDA_LD "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" > "$log" 2>&1 ;;
    *)           "$bin" pass 12 512 --threads 8 --proof-out "$out" "$@" > "$log" 2>&1 ;;
  esac
  local rc=$?
  CASES=$((CASES+1))
  grep -Ei 'gpu:|PROVE|ACCEPT|REJECT|PROOF sha256|error|panic' "$log" | head -5
  if [ "$rc" != 0 ]; then echo "FAILURE: $name [$label] prover exited $rc"; fail=1; return; fi
  if ! grep -q 'ACCEPT' "$log"; then echo "FAILURE: $name [$label] no ACCEPT from the verifier"; fail=1; return; fi
  case "$label" in
    gpu|gpu-zkchunk)
      if ! grep -q 'gpu: ON' "$log"; then
        echo "FAILURE: $name [$label] ran WITHOUT a device (no 'gpu: ON'); a CPU fallback is not a GPU gate"
        fail=1; return
      fi ;;
  esac
  if [ ! -f "$out" ]; then echo "FAILURE: $name [$label] produced no proof"; fail=1; return; fi
  local got gotb
  got=$(sha256sum "$out" | cut -d" " -f1)
  gotb=$(stat -c %s "$out")
  if [ "$got" = "$ref" ] && [ "$gotb" = "$refb" ]; then
    echo "GATE OK   $name [$label]  $got  $gotb B  (log retained: $log)"
  else
    echo "FAILURE: GATE $name [$label]"
    echo "   got  $got / $gotb B"
    echo "   want $ref / $refb B"
    fail=1
  fi
  rm -f "$out"
}

for L in cpu gpu gpu-zkchunk; do
  B=$CPU; [ "$L" = cpu ] || B=$GPU
  gate v2   50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d 66844928 "$B" $L
  gate v3   5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d 70758084 "$B" $L --profile v3 --export $V3
  gate zk   021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d 87228528 "$B" $L --zk --seed 1
  gate zkv3 40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17 87697008 "$B" $L --zk --seed 1 --profile v3 --export $V3
done

say "VERDICT"
echo "executed byte-gate cases: $CASES (expect 12)"
[ "$CASES" = 12 ] || { echo "FAILURE: expected 12 gate cases, ran $CASES"; fail=1; }
echo "retained logs: $(ls "$SP"/*.out 2>/dev/null | wc -l) in $SP"
if [ $fail = 0 ]; then echo "ALL CL1 FLOORS GREEN (12 byte gates + oracle suite + missing-feature refusal + tests + both builds)"; else echo "FAILURE: one or more CL1 floors RED — see above"; fi
exit $fail
