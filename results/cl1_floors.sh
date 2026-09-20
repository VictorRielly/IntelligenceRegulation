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
#     executed_cases must equal the suite's expectation and gpu_enabled must
#     be true;
#   * the MISSING-FEATURE refusal: on the CPU target (no gpu-cuda) the same
#     test file must FAIL under HL_GPU_REQUIRED=1 and must report zero cases
#     without it — a build that compiles the device tests away cannot pass as
#     a GPU gate;
#   * every gate's full prover log is RETAINED in the scratch dir (only the
#     proof bytes are deleted), and its PROOF sha256 line is echoed here.
#
# [ZK60-CL13] What changed after Codex's round-9 review (ZK60_ROUND9_REVIEW.md):
#   * EVIDENCE IS A MANIFEST, not a green substring. Every step is a CASE the
#     Python helper scripts/hashline_cl_gpu_gates.py `start`s and `record`s
#     (exit code, verifier verdict, `gpu: ON`, full proof SHA-256 + length
#     against the suite's FROZEN expectation, retained-log sha256, argv,
#     timestamps, the binary's digest); `finalize` computes the verdict. The
#     frozen digests live in the helper's suite definition (one source); the
#     preflight binds to the manifest's HEAD and GPU-binary digest.
#   * PARSER SELF-TESTS RUN FIRST — before any build or hardware step (they
#     ran after the oracle before). A helper that does not run stops the
#     script before it builds anything.
#   * PORTABLE: repository (from this file's location), export dirs, CUDA
#     paths, scratch, device selection and threads are explicit inputs with
#     the archived values as defaults; nothing about a checkout is fixed.
#   * TWO THREADS: prover --threads, CARGO_BUILD_JOBS and RAYON_NUM_THREADS
#     all default to 2 on this shared laptop (three hardcoded `--threads 8`
#     before).
#   * THE ORACLE'S CASE COUNT IS THE SUITE'S, not a floor of 20 (the archived
#     run had 49; a floor would not have noticed removed cases).
#   * --dry-run prints every command it WOULD run, fully resolved and quoted,
#     runs no build and no hardware job, and writes nothing under the scratch
#     dir (an optional --plan file elsewhere is the only output).
#
# [ZK60-CL21] The extracted core is in the provenance. hashline depends on
# zkp-core by path (hashline/Cargo.toml), so the core's source and BOTH
# Cargo.lock files are build inputs of every binary gated here; round 11's
# outer validator hashed both crates while this manifest identified hashline
# alone. Now:
#   * SOURCE IDENTITY covers both crates: each crate's tree id at HEAD, the
#     sha256 of its uncommitted delta, the sha256 of each Cargo.lock as it is
#     in the working tree, the core's presence (Cargo.toml, src/, the
#     example). `init --repo` records them; `finalize --repo` re-probes and
#     refuses a tree that changed during the run.
#   * A DIRTY OR MISSING CRATE STOPS THE RUN HERE, before any build (the
#     validator refuses it anyway; twelve minutes on a tree that cannot
#     qualify are pure cost). --dry-run only reports.
#   * SUITE VERSION 4 (archived) adds two cases: the core's own
#     `cargo test --release --locked --offline` (exactly 19 passed / 0 failed /
#     0 ignored, round 11's count) and its `public_sumcheck` example (exit 0 +
#     its identifying line). `--locked`: cargo refuses rather than rewrites
#     the lockfile the manifest hashed. v1–v3 runs skip the two cases but
#     still record the identity. v5 pins 22 core tests and adds protected-storage coverage. Default v9
#     pins 32 core and 227 storage-enabled hashline tests after FFN IO binding;
#     live untracked files refuse.
#
# LOCKS. The OUTER heavy lock (/tmp/zk-heavy.lock) is the LAUNCHER's job —
# wrap this script in `flock /tmp/zk-heavy.lock` in the detached launcher, as
# CLAUDE.md's no-hangup protocol says. This script takes /tmp/zk-build.lock
# INTERNALLY around each cargo step. NEVER wrap this script in the build lock:
# that is a self-deadlock (feedback-floors-wrapper-lock).
#
# Usage: cl1_floors.sh [options] <scratch-dir>
#   --repo DIR          repository root      (default: this script's ../ ; env HL_FLOORS_REPO)
#   --v3-export DIR     125M v3 export       (env HL_FLOORS_V3_EXPORT)
#   --m125-export DIR   M125_EXPORT_DIR      (env M125_EXPORT_DIR)
#   --cuda-root DIR     CUDA root            (env HL_FLOORS_CUDA_ROOT)
#   --cuda-ld PATHS     LD_LIBRARY_PATH for the GPU binary (env HL_FLOORS_CUDA_LD)
#   --threads N         prover --threads     (default 2; env HL_FLOORS_THREADS)
#   --build-jobs N      CARGO_BUILD_JOBS     (default 2; env CARGO_BUILD_JOBS)
#   --rayon-threads N   RAYON_NUM_THREADS    (default 2; env RAYON_NUM_THREADS)
#   --layers N --tokens N   the pass shape   (default 12 512 = the frozen fixtures;
#                       ANY OTHER SHAPE has no frozen byte expectation: the manifest
#                       records every proving case as no_frozen_expectation and the
#                       verdict CANNOT be green — use it only to exercise the runner)
#   --device LIST       CUDA_VISIBLE_DEVICES passthrough (env CUDA_VISIBLE_DEVICES)
#   --python BIN        the Python for the helper (default python3; env HL_FLOORS_PYTHON)
#   --gates FILE        the helper (default <repo>/scripts/hashline_cl_gpu_gates.py; env HL_FLOORS_GATES)
#   --suite-version V   the helper's suite version (default 10 = native/row-fold: zkp-core tests/example (37) + protected storage (288 passed, 2 capture writers ignored);
#                       v3 = CL18's 189-case oracle; v2 = CL15's 141; env HL_FLOORS_SUITE_VERSION)
#   --dry-run           print every command, run nothing heavy, write nothing under scratch
#   --plan FILE         with --dry-run: also write the command list to FILE
# The manifest lands at <scratch-dir>/manifest.json; per-case logs beside it.
set -u

SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
R=${HL_FLOORS_REPO:-$(readlink -f "$SCRIPT_DIR/..")}
V3=${HL_FLOORS_V3_EXPORT:-/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export}
M125=${M125_EXPORT_DIR:-/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl}
CUDA_ROOT_DIR=${HL_FLOORS_CUDA_ROOT:-/home/victor/cuda-root}
CUDA_LD=${HL_FLOORS_CUDA_LD:-}
THREADS=${HL_FLOORS_THREADS:-2}
JOBS=${CARGO_BUILD_JOBS:-2}
RAYON=${RAYON_NUM_THREADS:-2}
LAYERS=${HL_FLOORS_LAYERS:-12}
TOKENS=${HL_FLOORS_TOKENS:-512}
DEVICES=${CUDA_VISIBLE_DEVICES-}
PY=${HL_FLOORS_PYTHON:-python3}
GATES=${HL_FLOORS_GATES:-}
SUITE=${HL_FLOORS_SUITE_VERSION:-10}
DRY=0
PLAN=""
SP=""

usage () { sed -n '/^# Usage:/,/^set -u/p' "${BASH_SOURCE[0]}" | grep -v '^set -u' | sed 's/^# \{0,1\}//'; }
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) R=$2; shift 2 ;;
    --v3-export) V3=$2; shift 2 ;;
    --m125-export) M125=$2; shift 2 ;;
    --cuda-root) CUDA_ROOT_DIR=$2; shift 2 ;;
    --cuda-ld) CUDA_LD=$2; shift 2 ;;
    --threads) THREADS=$2; shift 2 ;;
    --build-jobs) JOBS=$2; shift 2 ;;
    --rayon-threads) RAYON=$2; shift 2 ;;
    --layers) LAYERS=$2; shift 2 ;;
    --tokens) TOKENS=$2; shift 2 ;;
    --device) DEVICES=$2; shift 2 ;;
    --python) PY=$2; shift 2 ;;
    --gates) GATES=$2; shift 2 ;;
    --suite-version) SUITE=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --plan) PLAN=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "unknown option $1" >&2; usage >&2; exit 2 ;;
    *) if [ -n "$SP" ]; then echo "one scratch dir only (got '$SP' and '$1')" >&2; exit 2; fi; SP=$1; shift ;;
  esac
done
[ -n "$SP" ] || { echo "scratchpad dir required" >&2; usage >&2; exit 2; }
[ -n "$CUDA_LD" ] || CUDA_LD=$CUDA_ROOT_DIR/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
[ -n "$GATES" ] || GATES=$R/scripts/hashline_cl_gpu_gates.py
export M125_EXPORT_DIR=$M125
CPU=$R/hashline/target/release/hashline
GPU=$R/hashline/target-gpu/release/hashline
MANIFEST=$SP/manifest.json
fail=0
EMITTED=0

say () { echo; echo "=== $* ==="; date '+%F %T'; }
# Every command goes through `run`/`run_to`: the fully resolved, `printf %q`
# quoted line is printed (and appended to --plan); in --dry-run nothing runs.
emit () {
  local line
  line=$(printf '%q ' "$@"); line=${line% }
  echo "+ $line"
  EMITTED=$((EMITTED+1))
  [ -z "$PLAN" ] || echo "$line" >> "$PLAN"
}
run () { emit "$@"; [ "$DRY" = 1 ] && return 0; "$@"; }
run_to () {
  local log=$1; shift
  local line
  line=$(printf '%q ' "$@"); line="${line% } > $(printf '%q' "$log") 2>&1"
  echo "+ $line"
  EMITTED=$((EMITTED+1))
  [ -z "$PLAN" ] || echo "$line" >> "$PLAN"
  [ "$DRY" = 1 ] && return 0
  "$@" > "$log" 2>&1
}

if [ "$DRY" = 1 ]; then
  echo "DRY RUN: commands are printed, nothing is built or launched, nothing is written under $SP"
  if [ -n "$PLAN" ]; then mkdir -p "$(dirname "$PLAN")"; : > "$PLAN"; fi
else
  mkdir -p "$SP"
fi

say "configuration"
echo "repo        $R"
echo "v3 export   $V3"
echo "M125 export $M125"
echo "CUDA root   $CUDA_ROOT_DIR"
echo "CUDA LD     $CUDA_LD"
echo "threads     prover --threads $THREADS | CARGO_BUILD_JOBS $JOBS | RAYON_NUM_THREADS $RAYON"
echo "shape       pass $LAYERS $TOKENS$( [ "$LAYERS $TOKENS" = "12 512" ] && echo ' (the frozen fixtures)' || echo ' (NOT the frozen shape: no byte expectation applies, the verdict cannot be green)')"
echo "devices     CUDA_VISIBLE_DEVICES=${DEVICES:-<unset: all>}"
echo "helper      $PY $GATES (suite version $SUITE)"
echo "scratch     $SP (manifest + per-case logs are retained here)"

# --------------------------------------------------------------------------
# 1. PARSER SELF-TESTS — FIRST. [round-7 review, Codex] the first version of
# the embedded parser put `\"` escapes inside f-string expressions, which
# Python 3.10 refuses (SyntaxError), so the gate could not have passed; and it
# was exercised only AFTER the hardware oracle had run (round-9 review). The
# helper's self-test (parser on valid / empty / missing / extra-brace /
# non-ASCII input, suite tables, a synthetic record->validate round trip) and
# the SAME shell expansion the real check uses run here, before anything else.
say "parser self-tests (before any build or hardware step)"
emit "$PY" "$GATES" self-test
if ! "$PY" "$GATES" self-test; then
  echo "FAILURE: the gates helper does not run on this Python ($PY $GATES); nothing was built, nothing was launched"; exit 1
fi
SELFTEST='{"executed_cases":99,"gpu_enabled":true,"gpu_required":true,"device":"self-test — non-ASCII on purpose"}'
# `${SUMMARY:-{}}` is NOT a JSON default in bash: the expansion ends at the
# first `}`, so a literal `}` was appended to a perfectly good summary and
# the decoder saw "extra data" — the gate went RED on a 49-case green run
# (results/cl_round7_floors_attempt3_bracebug.log). Quote the default.
if ! "$PY" "$GATES" oracle-summary --expected-cases 99 "${SELFTEST:-"{}"}" >/dev/null; then
  echo "FAILURE: the oracle-summary parser refused the self-test summary (or the expansion mangles it)"; exit 1
fi
EMPTY=""
if "$PY" "$GATES" oracle-summary --expected-cases 99 "${EMPTY:-"{}"}" >/dev/null 2>&1; then
  echo "FAILURE: the oracle-summary parser accepted an EMPTY summary"; exit 1
fi
ORACLE_EXPECTED_CASES=$("$PY" "$GATES" expected-cases --suite-version "$SUITE" --oracle-count) || { echo "FAILURE: no suite version $SUITE in the helper"; exit 1; }
# [ZK60-CL21] whether this suite version gates the extracted core (v4+)
CORE_CASES=0
if "$PY" "$GATES" expected-cases --suite-version "$SUITE" | grep -qx core_tests; then CORE_CASES=1; fi
echo "self-tests OK; suite version $SUITE expects $ORACLE_EXPECTED_CASES executed oracle cases; zkp-core cases: $( [ "$CORE_CASES" = 1 ] && echo 'core_tests + core_example' || echo 'none (v1-v3)')"

# --------------------------------------------------------------------------
# 2. SOURCE IDENTITY -> manifest skeleton.
# [ZK60-CL21] BOTH crates. hashline depends on zkp-core by path, so the
# core's tree, its delta and both lockfiles are build inputs of every
# binary gated here. The helper records the same facts through
# `init --repo` (and cross-checks HEAD and the hashline delta against the
# values read here); a dirty or missing crate stops the run BEFORE any build.
say "source identity"
HEAD=$(git --no-pager -C "$R" rev-parse HEAD 2>/dev/null || true)
BRANCH=$(git --no-pager -C "$R" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
DIRTY=$(git --no-pager -C "$R" status --porcelain --untracked-files=no 2>/dev/null | wc -l)
# [round-7 review] HEAD plus a dirty count cannot identify dirty build inputs;
# the content hash of the uncommitted delta under hashline/ can. On a clean
# checkout this is the hash of the empty diff (e3b0c442..).
DELTA=$(git --no-pager -C "$R" diff HEAD -- hashline 2>/dev/null | sha256sum | cut -d' ' -f1)
CORE_DELTA=$(git --no-pager -C "$R" diff HEAD -- zkp-core 2>/dev/null | sha256sum | cut -d' ' -f1)
HL_TREE=$(git --no-pager -C "$R" rev-parse HEAD:hashline 2>/dev/null || true)
CORE_TREE=$(git --no-pager -C "$R" rev-parse HEAD:zkp-core 2>/dev/null || true)
EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
lock_sha () { if [ -f "$1" ]; then sha256sum "$1" | cut -d' ' -f1; else echo "<missing>"; fi; }
HL_LOCK=$(lock_sha "$R/hashline/Cargo.lock")
CORE_LOCK=$(lock_sha "$R/zkp-core/Cargo.lock")
CORE_PRESENT=0
if [ -f "$R/zkp-core/Cargo.toml" ] && [ -d "$R/zkp-core/src" ] && [ -f "$R/zkp-core/examples/public_sumcheck.rs" ]; then CORE_PRESENT=1; fi
echo "HEAD      ${HEAD:-<not a git checkout>}"
echo "branch    ${BRANCH:-?}"
echo "dirty     $DIRTY tracked file(s) modified"
echo "hashline/  tree ${HL_TREE:-<none>}  dirty-delta sha256 $DELTA  Cargo.lock sha256 $HL_LOCK"
echo "zkp-core/  tree ${CORE_TREE:-<none>}  dirty-delta sha256 $CORE_DELTA  Cargo.lock sha256 $CORE_LOCK  present $CORE_PRESENT (Cargo.toml + src/ + examples/public_sumcheck.rs)"
if [ "$DRY" != 1 ]; then
  [ -n "$HEAD" ] || { echo "FAILURE: $R is not a git checkout; no source identity"; exit 1; }
  [ "$CORE_PRESENT" = 1 ] || { echo "FAILURE: the extracted core is missing or incomplete under $R/zkp-core (Cargo.toml, src/, examples/public_sumcheck.rs): the build inputs are incomplete; nothing was built"; exit 1; }
  [ "$DELTA" = "$EMPTY_SHA" ] || { echo "FAILURE: uncommitted changes under hashline/ (delta sha256 $DELTA): HEAD would not identify the build inputs and the manifest can never be green; commit first — nothing was built"; exit 1; }
  [ "$CORE_DELTA" = "$EMPTY_SHA" ] || { echo "FAILURE: uncommitted changes under zkp-core/ (delta sha256 $CORE_DELTA): HEAD would not identify the build inputs and the manifest can never be green; commit first — nothing was built"; exit 1; }
fi
NVSMI=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1 || true)
run "$PY" "$GATES" init --out "$MANIFEST" --suite-version "$SUITE" --repo "$R" --head "${HEAD:-unknown}" --branch "${BRANCH:-unknown}" \
  --dirty-count "$DIRTY" --dirty-delta-sha256 "$DELTA" --layers "$LAYERS" --tokens "$TOKENS" \
  --prover-threads "$THREADS" --build-jobs "$JOBS" --rayon-threads "$RAYON" \
  --cpu-target-dir "$R/hashline/target" --gpu-target-dir "$R/hashline/target-gpu" \
  --v3-export "$V3" --m125-export "$M125" --cuda-root "$CUDA_ROOT_DIR" --scratch "$SP" \
  --device-selection "${DEVICES:-}" --nvidia-smi "${NVSMI:-}" || { echo "FAILURE: manifest init"; exit 1; }

# --------------------------------------------------------------------------
# 3. BUILDS (each under the INTERNAL build lock).
build_case () {
  local id=$1; shift
  say "$id"
  run "$PY" "$GATES" start --manifest "$MANIFEST" --case "$id"
  run_to "$SP/$id.out" "$@"; local rc=$?
  [ "$DRY" = 1 ] || tail -2 "$SP/$id.out"
  run "$PY" "$GATES" record --manifest "$MANIFEST" --case "$id" --exit "$rc" --log "$SP/$id.out" -- "$@" \
    || { echo "FAILURE: $id"; exit 1; }
}
build_case build_cpu env "CARGO_BUILD_JOBS=$JOBS" flock /tmp/zk-build.lock \
  cargo build --release --manifest-path "$R/hashline/Cargo.toml"
build_case build_gpu env "CARGO_BUILD_JOBS=$JOBS" "CUDA_ROOT=$CUDA_ROOT_DIR" "LD_LIBRARY_PATH=$CUDA_LD" \
  "CARGO_TARGET_DIR=$R/hashline/target-gpu" flock /tmp/zk-build.lock \
  cargo build --release --features gpu-cuda --manifest-path "$R/hashline/Cargo.toml"

say "binary identity"
run "$PY" "$GATES" binaries --manifest "$MANIFEST" --cpu "$CPU" --gpu "$GPU" || { echo "FAILURE: binary identity"; exit 1; }

# --------------------------------------------------------------------------
# 4. CPU CRATE TESTS. record EVERY binary's result line: `tail` hid the lib
# suite's count on the first run, which left the log unable to show what the
# exit code had checked. --test-threads=2 is Codex's own CPU baseline
# (ZK60_CLAUDE_QUEUE.md). At the default parallelism three Codex
# `verifier_hardening_tests` race the pcs_compact lib tests, which
# `configure()` the PROCESS-GLOBAL compact PCS; that is a Codex-owned test
# hazard, recorded in the lane report, not a lane defect — and not something
# these floors should silently mask either, so it is named here.
say "cargo test --release (CPU, --test-threads=2)"
TEST_LOG=$SP/cargo_test_cpu.out
run "$PY" "$GATES" start --manifest "$MANIFEST" --case cargo_test_cpu
CMD=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON" flock /tmp/zk-build.lock
     cargo test --release --manifest-path "$R/hashline/Cargo.toml" -- --test-threads=2)
run_to "$TEST_LOG" "${CMD[@]}"; trc=$?
[ "$DRY" = 1 ] || grep -E '^test result:|^error|panicked' "$TEST_LOG"
run "$PY" "$GATES" record --manifest "$MANIFEST" --case cargo_test_cpu --exit "$trc" --log "$TEST_LOG" -- "${CMD[@]}" \
  || { echo "FAILURE: cargo test"; fail=1; }

# --------------------------------------------------------------------------
# 4b. THE EXTRACTED CORE (suite v4+). zkp-core's own tests and its terminal
# example, each a case with the SUITE'S tied expectation (v4: 19 passed / 0
# failed / 0 ignored summed over every result line; the example's
# identifying line). `--locked` makes cargo refuse rather than rewrite
# zkp-core/Cargo.lock, so the lockfile the manifest hashed is the one built
# against; `--offline` keeps the registry out of the identity. Both take the
# build lock like every other cargo step. The example binary's digest is
# recorded informationally (--artifact). A v1-v3 suite skips this section.
if [ "$CORE_CASES" = 1 ]; then
  say "zkp-core: cargo test --release --locked --offline (the extracted core, --test-threads=2)"
  CORE_TEST_LOG=$SP/core_tests.out
  run "$PY" "$GATES" start --manifest "$MANIFEST" --case core_tests
  CMD=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON" flock /tmp/zk-build.lock
       cargo test --release --locked --offline --manifest-path "$R/zkp-core/Cargo.toml" -- --test-threads=2)
  run_to "$CORE_TEST_LOG" "${CMD[@]}"; crc=$?
  [ "$DRY" = 1 ] || grep -E '^test result:|^error|panicked' "$CORE_TEST_LOG"
  run "$PY" "$GATES" record --manifest "$MANIFEST" --case core_tests --exit "$crc" --log "$CORE_TEST_LOG" -- "${CMD[@]}" \
    || { echo "FAILURE: zkp-core tests"; fail=1; }

  say "zkp-core: the public_sumcheck example (cargo run --release --locked --offline --example public_sumcheck)"
  CORE_EX_LOG=$SP/core_example.out
  run "$PY" "$GATES" start --manifest "$MANIFEST" --case core_example
  CMD=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON" flock /tmp/zk-build.lock
       cargo run --release --locked --offline --manifest-path "$R/zkp-core/Cargo.toml" --example public_sumcheck)
  run_to "$CORE_EX_LOG" "${CMD[@]}"; xrc=$?
  [ "$DRY" = 1 ] || tail -1 "$CORE_EX_LOG"
  run "$PY" "$GATES" record --manifest "$MANIFEST" --case core_example --exit "$xrc" --log "$CORE_EX_LOG" \
    --artifact "$R/zkp-core/target/release/examples/public_sumcheck" -- "${CMD[@]}" \
    || { echo "FAILURE: zkp-core example"; fail=1; }
else
  say "zkp-core cases: none in suite version $SUITE (v4+ gates the extracted core); its identity is recorded above regardless"
fi

# --------------------------------------------------------------------------
# 4c. Protected material / registration are opt-in and absent from default tests.
if "$PY" "$GATES" expected-cases --suite-version "$SUITE" | grep -qx storage_tests; then
  say "hashline: protected-storage feature tests (suite v5+)"
  STORAGE_LOG=$SP/storage_tests.out
  run "$PY" "$GATES" start --manifest "$MANIFEST" --case storage_tests
  # Cargo integration tests also build the normal binary. Keep the optional
  # feature's binary separate from the CPU artifact already hashed above.
  CMD=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON"
       "CARGO_TARGET_DIR=$R/hashline/target/storage-tests" flock /tmp/zk-build.lock
       cargo test --release --locked --offline --manifest-path "$R/hashline/Cargo.toml"
       --features stable-weight-storage -- --test-threads=2)
  run_to "$STORAGE_LOG" "${CMD[@]}"; src=$?
  [ "$DRY" = 1 ] || grep -E '^test result:|^error|panicked' "$STORAGE_LOG"
  run "$PY" "$GATES" record --manifest "$MANIFEST" --case storage_tests --exit "$src" --log "$STORAGE_LOG" -- "${CMD[@]}" \
    || { echo "FAILURE: protected-storage tests"; fail=1; }
fi

# --------------------------------------------------------------------------
# 5. THE DEVICE ORACLE (uncaptured, one thread), then its two controls.
say "CL1 GPU oracle suite (chunked hiding commit vs the CPU, + negative control) — uncaptured, one thread"
ORACLE_LOG=$SP/oracle_gpu.out
run "$PY" "$GATES" start --manifest "$MANIFEST" --case oracle_gpu
CMD=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON" "CUDA_ROOT=$CUDA_ROOT_DIR" "LD_LIBRARY_PATH=$CUDA_LD"
     "CARGO_TARGET_DIR=$R/hashline/target-gpu" HL_GPU=1 HL_GPU_REQUIRED=1)
[ -z "$DEVICES" ] || CMD+=("CUDA_VISIBLE_DEVICES=$DEVICES")
CMD+=(flock /tmp/zk-build.lock cargo test --release --features gpu-cuda --manifest-path "$R/hashline/Cargo.toml"
      --test zk60_gpu_commit -- --test-threads=1 --nocapture)
run_to "$ORACLE_LOG" "${CMD[@]}"; orc=$?
if [ "$DRY" != 1 ]; then
  grep -E '^test result:|panicked|FAILED' "$ORACLE_LOG" | head -5
  SUMMARY=$(grep 'ZK60_CL4_SUMMARY' "$ORACLE_LOG" | tail -1 | sed 's/^.*ZK60_CL4_SUMMARY //')
  echo "oracle summary: ${SUMMARY:-<none emitted>}"
  if [ "$orc" != 0 ]; then echo "FAILURE: CL1 GPU oracle suite exited $orc"; fail=1; fi
  # the quoted default (see the self-test above); the count is the SUITE's
  if ! "$PY" "$GATES" oracle-summary --expected-cases "$ORACLE_EXPECTED_CASES" "${SUMMARY:-"{}"}"; then
    echo "FAILURE: the oracle suite did not prove exactly $ORACLE_EXPECTED_CASES executed cases on an enabled device"; fail=1
  fi
fi
run "$PY" "$GATES" record --manifest "$MANIFEST" --case oracle_gpu --exit "$orc" --log "$ORACLE_LOG" -- "${CMD[@]}" || fail=1

say "missing-feature refusal (CPU target, no gpu-cuda): HL_GPU_REQUIRED=1 must FAIL"
NOFEAT_LOG=$SP/nofeature_required_refuses.out
run "$PY" "$GATES" start --manifest "$MANIFEST" --case nofeature_required_refuses
CMD=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON" HL_GPU_REQUIRED=1 flock /tmp/zk-build.lock
     cargo test --release --manifest-path "$R/hashline/Cargo.toml" --test zk60_gpu_commit -- --nocapture)
run_to "$NOFEAT_LOG" "${CMD[@]}"; nrc=$?
if [ "$DRY" != 1 ]; then
  if [ "$nrc" = 0 ]; then
    echo "FAILURE: a build WITHOUT gpu-cuda passed under HL_GPU_REQUIRED=1 (vacuous gate)"; fail=1
  elif grep -q 'built WITHOUT --features gpu-cuda' "$NOFEAT_LOG"; then
    echo "refused as required (exit $nrc): $(grep -o 'HL_GPU_REQUIRED=1 but this test binary was built WITHOUT --features gpu-cuda' "$NOFEAT_LOG" | head -1)"
  else
    echo "FAILURE: the no-feature run failed for an unexpected reason (exit $nrc); see $NOFEAT_LOG"; fail=1
  fi
fi
run "$PY" "$GATES" record --manifest "$MANIFEST" --case nofeature_required_refuses --exit "$nrc" --log "$NOFEAT_LOG" -- "${CMD[@]}" || fail=1

say "missing-feature status (CPU target, no gpu-cuda): without the requirement it must report ZERO cases, not success as evidence"
PLAIN_LOG=$SP/nofeature_plain_reports_zero.out
run "$PY" "$GATES" start --manifest "$MANIFEST" --case nofeature_plain_reports_zero
CMD=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON" flock /tmp/zk-build.lock
     cargo test --release --manifest-path "$R/hashline/Cargo.toml" --test zk60_gpu_commit -- --nocapture)
run_to "$PLAIN_LOG" "${CMD[@]}"; prc=$?
if [ "$DRY" != 1 ]; then
  PLAIN=$(grep 'ZK60_CL4_SUMMARY' "$PLAIN_LOG" | tail -1 | sed 's/^.*ZK60_CL4_SUMMARY //')
  echo "no-feature summary (exit $prc): ${PLAIN:-<none emitted>}"
  if [ "$prc" != 0 ] || ! echo "$PLAIN" | grep -q '"executed_cases":0,"gpu_enabled":false'; then
    echo "FAILURE: the no-feature run must pass AND report executed_cases 0 / gpu_enabled false"; fail=1
  fi
fi
run "$PY" "$GATES" record --manifest "$MANIFEST" --case nofeature_plain_reports_zero --exit "$prc" --log "$PLAIN_LOG" -- "${CMD[@]}" || fail=1

# --------------------------------------------------------------------------
# 6. THE BYTE GATES. [ZK60-CL4 review] gate <name> <label> <role> <binary> <args...>
#
# The first version compared `cut -c1-16` of the digest and ignored the proving
# subprocess's exit code entirely, so a truncated match or a crashed run that
# still left a file behind could have passed. Every gate is checked for:
#   * the proving subprocess's EXIT CODE
#   * the verifier's ACCEPT line
#   * device execution (`gpu: ON`) whenever the label is a GPU one
#   * the FULL SHA-256 and the exact byte length against the FROZEN expectation
#   * a freshly produced artifact (the output is removed before the run; the
#     proof's mtime must follow the case's start)
# [round-7 review] and the prover's own PROOF sha256 line is echoed, the log
# is RETAINED (only the proof bytes are deleted).
# [ZK60-CL13] the checks are performed by the helper's `record` from the suite
# definition (scripts/hashline_cl_gpu_gates.py FROZEN — the one source of the
# digests), which also records argv, binary digest and timestamps.
CASES=0
gate () {
  local name=$1 label=$2 role=$3 bin=$4; shift 4
  local id=$label-$name out=$SP/$label-$name.proof log=$SP/$label-$name.out
  say "GATE $name [$label]"
  local -a envs=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON")
  case "$label" in
    gpu)         envs+=(HL_GPU=1 "LD_LIBRARY_PATH=$CUDA_LD") ;;
    gpu-zkchunk) envs+=(HL_GPU=1 HL_ZK_CHUNK=1 "LD_LIBRARY_PATH=$CUDA_LD") ;;
  esac
  [ -z "$DEVICES" ] || envs+=("CUDA_VISIBLE_DEVICES=$DEVICES")
  local -a cmd=("$bin" pass "$LAYERS" "$TOKENS" --threads "$THREADS" --proof-out "$out" "$@")
  run rm -f "$out"
  run "$PY" "$GATES" start --manifest "$MANIFEST" --case "$id"
  run_to "$log" "${envs[@]}" "${cmd[@]}"; local rc=$?
  CASES=$((CASES+1))
  [ "$DRY" = 1 ] || grep -Ei 'gpu:|PROVE|ACCEPT|REJECT|PROOF sha256|error|panic' "$log" | head -5
  run "$PY" "$GATES" record --manifest "$MANIFEST" --case "$id" --exit "$rc" --log "$log" --proof "$out" \
    --binary-role "$role" --binary-path "$bin" -- "${envs[@]}" "${cmd[@]}" || fail=1
  run rm -f "$out"
}

for L in cpu gpu gpu-zkchunk; do
  B=$CPU; ROLE=cpu
  if [ "$L" != cpu ]; then B=$GPU; ROLE=gpu; fi
  gate v2   "$L" "$ROLE" "$B"
  gate v3   "$L" "$ROLE" "$B" --profile v3 --export "$V3"
  gate zk   "$L" "$ROLE" "$B" --zk --seed 1
  gate zkv3 "$L" "$ROLE" "$B" --zk --seed 1 --profile v3 --export "$V3"
done

# --------------------------------------------------------------------------
# 7. THE CACHE CASES — separate prover PROCESSES, as zk60_gpu_cache.rs runs
# them (CPU binary, HL_WCACHE_VERBOSE=1): a COLD process into an empty cache
# directory, a WARM one into the same directory (hits > 0 in its report
# line), both producing the frozen zkv3 proof; then the P3 + cache request,
# which must be REFUSED (exit 2, `REFUSED: --wcache with --p3.` first) before
# any proof — its export path does not exist, so a refusal that came after
# opening the export would not hold either.
WC=$SP/wcache
run rm -rf "$WC"
cache_case () {
  local id=$1; shift
  local out=$SP/$id.proof log=$SP/$id.out
  say "CACHE $id"
  local -a envs=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON" HL_WCACHE_VERBOSE=1)
  local -a cmd=("$CPU" pass "$LAYERS" "$TOKENS" --threads "$THREADS" --proof-out "$out" "$@")
  run rm -f "$out"
  run "$PY" "$GATES" start --manifest "$MANIFEST" --case "$id"
  run_to "$log" "${envs[@]}" "${cmd[@]}"; local rc=$?
  [ "$DRY" = 1 ] || grep -Ei 'wcache .*: hits|ACCEPT|REJECT|PROOF sha256|error|panic' "$log" | head -5
  run "$PY" "$GATES" record --manifest "$MANIFEST" --case "$id" --exit "$rc" --log "$log" --proof "$out" \
    --binary-role cpu --binary-path "$CPU" -- "${envs[@]}" "${cmd[@]}" || fail=1
  run rm -f "$out"
}
cache_case cache_cold_zkv3 --zk --seed 1 --profile v3 --export "$V3" --wcache "$WC"
cache_case cache_warm_zkv3 --zk --seed 1 --profile v3 --export "$V3" --wcache "$WC"

say "CACHE cache_p3_refusal (--p3 with --wcache must be refused before any work)"
P3_LOG=$SP/cache_p3_refusal.out
run "$PY" "$GATES" start --manifest "$MANIFEST" --case cache_p3_refusal
CMD=(env "CARGO_BUILD_JOBS=$JOBS" "RAYON_NUM_THREADS=$RAYON" "$CPU" pass "$LAYERS" "$TOKENS" --threads "$THREADS"
     --profile v3 --seed 1 --export /nonexistent/zk60-cl13-export --p3 --wcache "$WC-p3-must-not-exist")
run_to "$P3_LOG" "${CMD[@]}"; p3rc=$?
if [ "$DRY" != 1 ]; then
  head -1 "$P3_LOG"
  if [ -e "$WC-p3-must-not-exist" ]; then echo "FAILURE: the refused P3 run CREATED its cache directory"; fail=1; fi
fi
run "$PY" "$GATES" record --manifest "$MANIFEST" --case cache_p3_refusal --exit "$p3rc" --log "$P3_LOG" \
  --binary-role cpu --binary-path "$CPU" -- "${CMD[@]}" || fail=1

# --------------------------------------------------------------------------
# 8. VERDICT — computed by the helper's validator over the manifest, never
# written by hand. The human-readable line below is for the reader; the
# preflight reads the manifest.
say "VERDICT"
echo "executed byte-gate cases: $CASES (expect 12)"
[ "$CASES" = 12 ] || { echo "FAILURE: expected 12 gate cases, ran $CASES"; fail=1; }
[ "$DRY" = 1 ] || echo "retained logs: $(ls "$SP"/*.out 2>/dev/null | wc -l) in $SP"
# [ZK60-CL21] finalize re-probes the checkout: a crate tree or lockfile that
# changed during the run makes the verdict red.
run "$PY" "$GATES" finalize --manifest "$MANIFEST" --repo "$R" || fail=1
if [ "$DRY" = 1 ]; then
  echo "DRY RUN COMPLETE: $EMITTED commands emitted (self-test -> identity -> builds -> tests -> zkp-core -> oracle -> controls -> gates -> cache -> finalize); nothing built, nothing launched, nothing written under $SP"
  exit 0
fi
if [ $fail = 0 ]; then
  CORE_NOTE=""
  [ "$CORE_CASES" = 1 ] && CORE_NOTE=" + zkp-core tests + zkp-core example"
  echo "ALL CL1 FLOORS GREEN (12 byte gates + oracle suite + missing-feature refusal + cache cases + tests + both builds$CORE_NOTE; identity: hashline + zkp-core trees, both lockfiles) — manifest $MANIFEST"
else
  echo "FAILURE: one or more CL1 floors RED — see above and $MANIFEST"
fi
exit $fail
