#!/bin/bash
# [ZK60-CL5] The profile matrix at SAFE 125M shapes.
#
# Small repeated diagnostic runs, under the shared heavy lock, on the 8 GB
# laptop. NOT a headline benchmark: the box is not quiesced-certified and no
# p95 is produced here. Each configuration runs REPS times so run-to-run
# spread is visible rather than assumed away.
#
# Covers the axes CL5 asks to separate: P0 (no ZK) / P1 (public W, hiding
# activations) / P3 (private W), and a COLD vs WARM public weight cache.
#
# Round 7 (Codex review, 2026-09-06). The earlier version recorded each
# prover's exit code with `echo "exit $rc"` but never acted on it: a nonzero
# exit, a `gpu: off` line, a REJECT or a missing proof file all flowed through
# to `=== DONE ===` and exit 0, and neither the per-run proof digest nor the
# cache state was kept. The archived results/cl5_matrix.log (2026-09-04) was
# produced by THAT version — its fifteen rows do carry `exit 0`, `gpu: ON`
# and ACCEPT lines, so this is not a claim that those proofs failed, only
# that the runner did not enforce them. This version is fail-closed:
#   - every prover invocation must exit 0, print `gpu: ON`, print an ACCEPT
#     line with `"verified":true` in HASHLINE_TIMING, and leave a proof file
#     whose sha256 and length equal the `PROOF sha256 ... (N B)` line (the
#     binary hashes exactly the bytes it writes to --proof-out);
#   - repeats of one configuration must reproduce the same proof bytes
#     (deterministic --seed), and the three P1 configurations (cold / warm /
#     no cache) must produce identical proofs — the weight cache's contract
#     is byte identity, so a difference is a finding, not noise;
#   - HL_WCACHE_VERBOSE=1 is set on every run so the cache state is in the
#     log itself: cold must show 12 MISS / 0 HIT, warm 12 HIT / 0 MISS, and
#     the uncached configurations no wcache lines at all;
#   - per run, the exact command (first line of the run's own log, `CMD:`),
#     the exit code (last line, `exit N`), the proof's full sha256 + bytes,
#     the cache hit/miss counts, git HEAD, the dirty-file count under
#     hashline/, and the binary's sha256 go to $SP/cl5_evidence.tsv and are
#     echoed into the matrix log as `EVIDENCE` lines;
#   - the executed case count is checked against the expected 5 x REPS;
#   - the FIRST failure prints a FAILURE line and exits 1 (on this box a GPU
#     failure can be a VRAM freeze; continuing past one is not safe). DONE is
#     printed only after every case passed and the count matched.
# The hardened runner has NOT been re-executed in round 7 (the GPU was in
# use); the archived log predates it.
set -u
R=/home/victor/wt-zk60-cl1
SP="${1:?scratchpad dir required}"
REPS="${2:-3}"
V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export
export M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
GPU=$R/hashline/target-gpu/release/hashline
LAYERS=12                       # `pass 12 512`: one wcache line per layer
CONFIGS=5                       # p0, p1cold, p1warm, p3, p1nocache
EXPECT=$((CONFIGS * REPS))
EXECUTED=0
EVIDENCE=$SP/cl5_evidence.tsv
declare -A TAG_SHA              # tag -> proof sha256 of its first rep
mkdir -p "$SP"

say () { echo; echo "=== $* ==="; date '+%F %T'; }
die () {   # fail-closed: the first failure ends the matrix. DONE is never printed after this.
  echo "FAILURE: $*"
  echo "executed matrix cases: $EXECUTED (expect $EXPECT) — INCOMPLETE"
  exit 1
}

# --- preflight: the identity of what is about to run --------------------------
[ -x "$GPU" ] || die "prover binary missing or not executable: $GPU"
[ -d "$V3" ] || die "v3 export missing: $V3"
HEAD=$(git -C "$R" rev-parse HEAD) || die "cannot read git HEAD of $R"
DIRTY=$(git -C "$R" status --porcelain -- hashline | wc -l)
BIN_SHA=$(sha256sum "$GPU" | cut -d' ' -f1)
echo "git HEAD $HEAD (uncommitted tracked changes under hashline/: $DIRTY)"
echo "binary $GPU sha256 $BIN_SHA"
echo "export $V3"
nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader || die "nvidia-smi failed: no GPU visible"
printf 'tag\trep\texit\tgpu\tverdict\tproof_sha256\tproof_bytes\twcache_hits\twcache_misses\tcache_state\thead\tdirty\tbinary_sha256\tcommand\n' > "$EVIDENCE"

# run_case <tag> <rep> <expected cache state: none|cold|warm> <prover args...>
run_case () {
  local tag=$1 rep=$2 want=$3; shift 3
  local log=$SP/$tag.$rep.log proof=$SP/$tag.$rep.proof
  local cmd="HL_GPU=1 HL_WCACHE_VERBOSE=1 $GPU pass 12 512 --threads 8 --profile v3 --export $V3 --proof-out $proof $*"
  say "$tag rep $rep"
  nvidia-smi --query-gpu=memory.used --format=csv,noheader
  rm -f "$proof"
  echo "CMD: $cmd" > "$log"          # the exact command is the first line of the run's own log
  HL_GPU=1 HL_WCACHE_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD "$GPU" pass 12 512 --threads 8 \
    --profile v3 --export "$V3" --proof-out "$proof" "$@" >> "$log" 2>&1
  local rc=$?
  echo "exit $rc" | tee -a "$log"    # and the exit code is its last line
  EXECUTED=$((EXECUTED + 1))
  # --- the gates: each one is a refusal, not a note ---------------------------
  [ "$rc" -eq 0 ] || die "$tag rep $rep: prover exit $rc (log $log)"
  grep -q '^  gpu: ON' "$log" || die "$tag rep $rep: no 'gpu: ON' line — this was not a GPU run (log $log)"
  local verdict; verdict=$(grep -oE '^PASS[^ ]* (ACCEPT|REJECT)' "$log" | head -1)
  [[ "$verdict" == *ACCEPT ]] || die "$tag rep $rep: verdict '${verdict:-none}' is not ACCEPT (log $log)"
  grep -q '^HASHLINE_TIMING ' "$log" || die "$tag rep $rep: no HASHLINE_TIMING line (log $log)"
  grep -q '"verified":true' "$log" || die "$tag rep $rep: HASHLINE_TIMING does not say verified:true (log $log)"
  grep -q 'declined (' "$log" && die "$tag rep $rep: a GPU stage declined to the CPU path (log $log)"
  [ -s "$proof" ] || die "$tag rep $rep: proof file missing or empty: $proof"
  local psha pbytes lsha lbytes pline
  psha=$(sha256sum "$proof" | cut -d' ' -f1)
  pbytes=$(stat -c %s "$proof")
  pline=$(grep -m1 -E '^PROOF sha256 ' "$log")
  if [[ "$pline" =~ ^PROOF\ sha256\ ([0-9a-f]{64})\ \(([0-9]+)\ B\) ]]; then
    lsha=${BASH_REMATCH[1]}; lbytes=${BASH_REMATCH[2]}
  else
    die "$tag rep $rep: no parseable PROOF sha256 line (log $log)"
  fi
  [ "$psha" = "$lsha" ] || die "$tag rep $rep: proof file sha256 $psha != PROOF line $lsha"
  [ "$pbytes" = "$lbytes" ] || die "$tag rep $rep: proof file is $pbytes B but the PROOF line says $lbytes B"
  if [ -n "${TAG_SHA[$tag]:-}" ] && [ "${TAG_SHA[$tag]}" != "$psha" ]; then
    die "$tag rep $rep: proof sha256 $psha differs from rep 1's ${TAG_SHA[$tag]} — a seeded repeat did not reproduce"
  fi
  TAG_SHA[$tag]=$psha
  # --- cache state, from the log itself ---------------------------------------
  local hits misses rejected state
  hits=$(grep -c 'wcache HIT' "$log"); misses=$(grep -c 'wcache MISS' "$log"); rejected=$(grep -c 'wcache entry .* REJECTED' "$log")
  [ "$rejected" -eq 0 ] || die "$tag rep $rep: $rejected wcache entries REJECTED (log $log)"
  case "$want" in
    cold) [ "$misses" -eq "$LAYERS" ] && [ "$hits" -eq 0 ] || die "$tag rep $rep: expected a COLD cache ($LAYERS MISS / 0 HIT), got $misses MISS / $hits HIT"; state=cold ;;
    warm) [ "$hits" -eq "$LAYERS" ] && [ "$misses" -eq 0 ] || die "$tag rep $rep: expected a WARM cache ($LAYERS HIT / 0 MISS), got $hits HIT / $misses MISS"; state=warm ;;
    none) [ "$hits" -eq 0 ] && [ "$misses" -eq 0 ] || die "$tag rep $rep: expected no cache, got $hits HIT / $misses MISS"
          [[ "$cmd" != *--wcache* ]] || die "$tag rep $rep: --wcache in the command of an uncached configuration"; state=none ;;
    *) die "run_case: unknown expected cache state '$want'" ;;
  esac
  echo "EVIDENCE $tag rep $rep: exit $rc | gpu ON | $verdict | proof sha256 $psha ($pbytes B) | wcache hits $hits misses $misses ($state) | HEAD $HEAD | binary $BIN_SHA"
  printf '%s\t%s\t%s\tON\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$tag" "$rep" "$rc" "$verdict" "$psha" "$pbytes" "$hits" "$misses" "$state" "$HEAD" "$DIRTY" "$BIN_SHA" "$cmd" >> "$EVIDENCE"
  grep -E '^HASHLINE_TIMING' "$log"
  rm -f "$proof"                     # the digest and length are kept; the 88 MB proof is not
}

say "P0 — no ZK, public everything"
for i in $(seq 1 "$REPS"); do run_case p0 "$i" none; done

say "P1 — hiding activations, PUBLIC weights, COLD weight cache"
WC=$SP/wcache-cold
for i in $(seq 1 "$REPS"); do
  rm -rf "$WC"; mkdir -p "$WC"        # every cold rep starts from an empty directory
  run_case p1cold "$i" cold --zk --seed 1 --wcache "$WC"
done

say "P1 — WARM weight cache (same directory reused, populated by the last cold rep)"
for i in $(seq 1 "$REPS"); do run_case p1warm "$i" warm --zk --seed 1 --wcache "$WC"; done

say "P3 — PRIVATE weights, cache refused by the mode (so none is configured)"
for i in $(seq 1 "$REPS"); do run_case p3 "$i" none --p3 --seed 1; done

say "P1 — no cache directory (the byte-gate configuration)"
for i in $(seq 1 "$REPS"); do run_case p1nocache "$i" none --zk --seed 1; done

# --- the cross-configuration byte gate: the cache must not change the proof ---
if [ "${TAG_SHA[p1cold]}" != "${TAG_SHA[p1warm]}" ] || [ "${TAG_SHA[p1cold]}" != "${TAG_SHA[p1nocache]}" ]; then
  die "P1 proofs differ across cache states: cold ${TAG_SHA[p1cold]} warm ${TAG_SHA[p1warm]} nocache ${TAG_SHA[p1nocache]}"
fi
echo "P1 byte gate: cold == warm == nocache == ${TAG_SHA[p1cold]}"

echo "executed matrix cases: $EXECUTED (expect $EXPECT)"
[ "$EXECUTED" -eq "$EXPECT" ] || die "case count mismatch: executed $EXECUTED, expected $EXPECT"
echo "evidence: $EVIDENCE"
say "DONE"
exit 0
