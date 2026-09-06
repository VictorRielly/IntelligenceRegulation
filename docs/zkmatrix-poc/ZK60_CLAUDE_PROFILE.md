# CL5 — where the post-CL1 GPU time actually goes

Task: `zk60_claude_tasks.json` CL5. Tool: `scripts/hashline_cl_profile.py`
(10 tests at delivery; 34 after the round-7 response in §5). Matrix:
`results/cl5_profile_matrix.sh`, log `results/cl5_matrix.log`, marker 0 —
that log was produced by the PRE-round-7 runner (see §5: the hardened runner
has not been re-executed).

**Diagnostic, not a headline.** Safe 125M shapes (12 x 512, d 768 / f 2048),
three repeats per configuration, under the shared heavy lock, on the 8 GB
laptop. The box is **not quiesced-certified**, so no p95 is produced and none
of these seconds may be published as a target number. `gpu: ON` and zero CPU
fallbacks were confirmed on every run.

The parser creates no new clock: it reads `HASHLINE_TIMING`, the
`prover phases` block and the `gpu device-side` counters that the prover
already emits, and refuses a log that lacks the machine-readable line.

---

## 1. The matrix [MEASURED, WSL-BOX, RTX 4070, n=3, median]

| config | mode | prove s | proof-ready s | proof bytes | VRAM | spread |
|---|---|---:|---:|---:|---:|---:|
| p0 | P0 | **2.235** | 3.950 | 70,758,084 | 2,430 MB | 0.9% |
| p1 no cache | P1 | 5.377 | 7.250 | 87,697,008 | 3,068 MB | 2.9% |
| p1 warm cache | P1 | 5.436 | 7.305 | 87,697,008 | 3,068 MB | 2.5% |
| p1 cold cache | P1 | 5.476 | 7.346 | 87,697,008 | 3,068 MB | 4.3% |
| p3 | P3 | **5.824** | 7.701 | 88,189,680 | 3,235 MB | **14.9%** |

**ZK is the expensive step, not privacy of the weights.** P0 -> P1 is
2.235 -> 5.476 s = **2.45x**. P1 -> P3 is 5.476 -> 5.824 = **+6.4%**, and P3's
own spread is 14.9%, so at this width that difference is barely outside noise.
Bytes: P1 -> P3 is +492,672 B = **+0.56%**.

**P3's spread is the outlier and is worth watching**: 14.9% against 0.9-4.3%
everywhere else. Three runs cannot say why; it is recorded as an observation,
not diagnosed.

**[Round-7 correction, in place.]** "Barely outside noise" above overstated
it. The P1 -> P3 difference (+6.4% on the medians) is INSIDE the recorded P3
spread (14.9% over three runs: 5.548 / 5.824 / 6.371 s prove). It is not
statistically separated from that spread, and it must not be extrapolated to
full-model proof readiness. Three noisy repeats at a 125M FFN shape are
diagnostic evidence, nothing more — as the review says.

---

## 2. THE PUBLIC WEIGHT CACHE IS NOT PAYING, AND THE REASON IS STRUCTURAL

Cold, warm and *absent* are indistinguishable above. That is not because the
cache misses — it hits. With `HL_WCACHE_VERBOSE=1`:

```
MISS -> wrote v3-l00-....wc (4.2 MB, commit 0.087 s, write 0.002 s)
HIT     v3-l00-....wc (rows 288, 4.2 MB, load+verify 0.008 s, re-encode 0.088 s)
```

**A HIT still RE-ENCODES.** `wcache::commit_w` stores the Merkle tree and, on a
hit, calls `reencode_store` to rebuild the encoded store from the data. So the
cache saves the *hashing*, never the *encoding* — and the encoding is the
expensive half. Per layer at this width: a miss costs ~0.031 s of commit, a
hit ~0.019 s of re-encode, so the saving is ~0.012 s x 12 layers = ~0.14 s of
a 5.4 s prove, i.e. **~2.6% at best, inside the run-to-run spread.**

This is a description of existing behaviour, not a regression: the cache was
built to avoid re-committing, and it does. It is simply worth far less than
its name suggests, and **a plan that assumes warm-cache proofs are materially
cheaper is assuming something these numbers do not support.**

Whether it pays better at Mistral width is not answered here; `commit W` is a
larger share there, but the re-encode scales with it too.

---

## 3. The top three exclusive costs [P1, the fast tier]

Against the proof-ready clock of 7.346 s:

| # | phase | exclusive s | share of proof-ready | bounded gain if removed ENTIRELY |
|---|---|---:|---:|---:|
| 1 | commit A (zk) | 1.390 | 18.9% | 1.23x |
| 2 | helpers + commit H (zk) | 1.312 | 17.9% | 1.22x |
| 3 | commit W | 0.795 | 10.8% | 1.12x |

**These bounds are independent and MUST NOT be multiplied.** Removing all
three entirely would be 7.346 -> 3.849 = 1.91x, not 1.23 x 1.22 x 1.12 = 1.68x
— and neither number is achievable, because "removed entirely" is not a thing
any change does. The tool emits this warning with every ranking.

The eleven named phases sum to within **0.589 ms** of the prove clock, so the
decomposition is exhaustive and there is no hidden pool of prove time to
attack. Outside the prove clock, witness load+chain is 1.74 s (23.7% of
proof-ready) and serialization 0.116 s (1.6%).

---

## 4. The optimisation order this profile actually supports

1. **The three commitments dominate: A, H and W together are 47.6% of
   proof-ready.** They share one mechanism — commit, encode, hash, open — so
   work there is the only thing with real leverage, and it is where CL6/CL7
   should look. AO's L9 work already improved the encode; this says the
   *commitments* are now the shape to attack, not the openings (`pcs openings`
   is 0.551 s, 7.5%).
2. **Witness load+chain at 23.7% is the second-largest single item** and is
   host work outside the prove clock entirely. It has never been owned by a
   lane.
3. **The weight cache is not an optimisation target — it is already spent.**
   Making it hit more often cannot buy more than the ~2.6% above; making a hit
   skip the re-encode would be a real change and belongs to whoever owns
   `wcache.rs` (not this lane).

**What this profile does NOT support:** any 8B projection. These are 125M
shapes; the phase mix at Mistral width is different (CL1 rung 5 measured
`commit W` at ~44% of the prove there, against 10.8% here). Old FFN-only or
lattice projections are not carried forward, per CL5's own instruction.

---

## 5. Round-7 review response (Codex, 2026-09-06)

Review: `ZK60_CL5_CL9_REVIEW.md` § CL5. Nothing in this round ran on the
GPU or proved anything; every change is pinned by CPU unit tests:

```
python3 -m unittest discover -s tests -p 'test_hashline_cl_profile.py'   # 34 tests, OK
```

(the original ten, unchanged in what they assert, plus 24 new ones in the
`Gate`, `Cache` and `Cli` classes). The shared fixture now ends with the
runner's `exit 0` line, exactly as `results/cl5_sample_p1cold.log` does,
because exit evidence is now required before a row may be ranked.

### 5.1 Finding by finding

**"A row explicitly marked `exit_code=1` still receives a ranked speedup
table."** — Confirmed; the earlier `rank()` looked only at the phases. Every
row now carries `eligible: bool` and `ineligible_reasons: [...]`; `rank()`
raises `ProfileError` naming the row and its reasons for ANY ineligible row.
Diagnostic rows are retained in the JSON (`rows`, marked, counted in
`diagnostic_rows`) and listed under `ranking.excluded_diagnostic_rows`; they
are never ranked. With no eligible row the CLI refuses (exit 2). Tests:
`Gate.test_exit_code_1_row_is_retained_but_never_ranked`,
`Cli.test_diagnostic_rows_are_retained_marked_and_excluded_from_ranking`.

**"A phase larger than the proof-ready clock produces a negative claimed
speedup bound (-7.34575353)."** — Confirmed: `ready / (ready - phase)` with
`phase = ready + 1` on the archived sample gives exactly that. Two layers now
refuse it: the gate marks the row ineligible (`phase 'X' (N s) is not smaller
than the proof-ready clock (R s): the Amdahl bound would be negative or
infinite`), and `rank()` re-checks every phase against the clock on its own,
so a row whose flag was forged to eligible is still refused. `phase == ready`
(infinite bound) is refused too. Test:
`Gate.test_a_phase_larger_than_proof_ready_is_refused_not_negative`, which
uses the review's control (a phase of `proof_ready_s + 1`) and asserts no
negative number appears in the message.

**"Require a validated accepted/serialized row with finite nonnegative
clocks, consistent proof length/verdict, and sensible phase totals before
ranking."** — The gate, in full (each is a refusal, not a note):

- exit code known (from the log's `exit N` line, or given) and `== 0`; a
  given exit code that contradicts the log's line is a refusal, not an
  override; the same for `CMD:` vs `--command`;
- `PASS* ACCEPT` present; `HASHLINE_TIMING` `verified == true` and
  `serialized == true`;
- `witness_s`, `prove_s`, `serialize_s`, `proof_ready_s`, `verify_s` present,
  numeric, finite, `>= 0`; `proof_ready_s > 0`;
- shape fields positive integers; privacy in {P0, P1, P3}; coverage present;
- `PROOF sha256 ... (N B)` present and `N == proof_bytes` in the JSON; the
  PASS line's `proof N B`, when present, equal as well;
- a GPU row is a GPU row all the way through: `gpu_requested`, `gpu_enabled`
  and the `gpu: ON` line must agree (any two disagreeing is a refusal); a
  pure CPU row (nothing claims a GPU) is eligible as a CPU row;
- a `prover phases` block exists; every phase `>= 0`, `<= prove_s + tol`,
  `< proof_ready_s`; the phase sum `<= prove_s + tol` and `<= proof_ready_s
  + tol`; `witness + prove + serialize <= proof_ready_s + tol`.

`tol` is 1 ms per named phase (11 ms for these rows) and is reported on the
row as `tolerance_s`. Why: each phase is printed `{:.3} s`, so it carries up
to 0.5 ms of rounding, and eleven rounded values can legitimately sum to
5.5 ms MORE than the 9-decimal prove clock while describing the same work;
1 ms per phase is twice that worst case. The tolerance only ever excuses a
small NEGATIVE residual. A positive residual of any size is reported as
unknown time (`unknown_exclusive_s`), never gated — exactly as before.
Tests: `Gate.test_negative_clock_is_ineligible`,
`Gate.test_contradictory_proof_bytes_is_ineligible`,
`Gate.test_verified_false_or_reject_is_ineligible`,
`Gate.test_gpu_contradictions_are_ineligible`,
`Gate.test_a_phase_larger_than_prove_but_inside_proof_ready_is_ineligible`
(which also pins `tolerance_s == 0.011`).

**"Include tests for missing/contradictory metadata and non-finite
values."** — Non-finite values are refused AT PARSE, before a row exists:
`NaN`, `Infinity`, `-Infinity` in the JSON (via `parse_constant`), a literal
that overflows to inf (`1e999`), a phase printed as `NaN s`/`inf s` (the
phase regex now captures `\S+`, so a non-number is seen and refused instead
of failing to match and vanishing into "unknown" time), a non-finite
device-side counter, and unparseable JSON. Tests:
`Gate.test_non_finite_values_are_refused_at_parse`,
`Cli.test_a_non_finite_log_is_refused_on_the_command_line`,
`Gate.test_missing_exit_code_is_ineligible`,
`Gate.test_contradictory_exit_code_is_ineligible`,
`Gate.test_the_command_is_read_from_the_log_and_checked`.

**"The parser currently accepts command/exit metadata externally and does
not attach cache state itself."** — The parser now reads the runner's
`CMD: ...` (first line) and `exit N` (last line) from the log; the external
arguments remain for old logs and are cross-checked, not trusted. Cache
state is derived from the log's own `HL_WCACHE_VERBOSE=1` lines — full
format, verbatim from `src/wcache.rs` (the excerpt in §2 above dropped the
prefix):

```
[UPERF3-AC] wcache MISS -> wrote <path>.wc (4.2 MB, commit 0.087 s, write 0.002 s)
[UPERF3-AC] wcache HIT <path>.wc (rows 288, 4.2 MB, load+verify 0.008 s, re-encode 0.088 s)
[UPERF3-AC] wcache entry <path>.wc REJECTED (<reason>); re-committing
```

plus the driver summary `wcache <dir>: hits N | misses N | rejected N | ...`
when present (only `pass_v3`, the P0 path, prints it; `pass_zk` does not —
see §5.3). Labels: `cold` (MISS only), `warm` (HIT only), `mixed`, `none`
(no `--wcache` in the command and no lines), `refused` (the P3 refusal
line), `unknown` (`--wcache` in the command but no lines because verbose was
off, or no command known). Contradictions are refusals: wcache lines with no
`--wcache` in the command; a summary that disagrees with the per-layer
lines. Per-entry timings (`load+verify`, `re-encode`, `commit`, `write`) are
kept on the row, so the "a HIT still re-encodes" observation of §2 is now
machine-readable. Tests: the eight `Cache.*` tests.

**"The archived sample parses as eligible."** —
`Gate.test_the_archived_sample_parses_as_eligible` reads
`results/cl5_sample_p1cold.log` and asserts eligible, exit 0 from the log's
own line, sha256 `40eb5479...aac17`, 87,697,008 B, zero fallbacks, and the
ranking of §3 (commit A first). Its cache state is honestly `unknown`: the
command had `--wcache`, but the log was recorded without
`HL_WCACHE_VERBOSE` and the ZK pass prints no summary, so the log itself
cannot say whether it hit. That is a note on the row, not a refusal.

**"`cl5_profile_matrix.sh` records prover exit codes but does not fail when
they are nonzero; its final DONE can still return zero. Fix the runner's
acceptance and exact case count, and record actual command, cache
state/hits, source/binary hashes and per-run proof digest."** — Confirmed;
the old runner's `echo "exit $rc"` was a record, not a gate. The runner is
now fail-closed: every invocation must exit 0, print `gpu: ON`, an ACCEPT
line and `"verified":true`, have no `declined (` fallback line, and leave a
proof file whose sha256 and length equal the `PROOF sha256 ... (N B)` line
(the binary hashes exactly the bytes it writes to `--proof-out`). Repeats
of one configuration must reproduce the same proof (deterministic `--seed`),
and cold / warm / no-cache P1 proofs must be identical (the cache's contract
is byte identity). `HL_WCACHE_VERBOSE=1` is set on every run and the counts
are enforced: cold = 12 MISS / 0 HIT, warm = 12 HIT / 0 MISS, uncached = no
lines. Per run it writes the exact command as the first line of the run's
own log (`CMD:`), the exit code as the last (`exit N`), and an `EVIDENCE`
line plus a row in `$SP/cl5_evidence.tsv` with proof sha256 + bytes, cache
hits/misses/state, git HEAD, the count of uncommitted tracked changes under
`hashline/`, and the binary's sha256. It prints `executed matrix cases: N
(expect M)` with M = 5 x REPS, and the FIRST failure prints `FAILURE: ...`
and exits 1 — deliberately not continuing, because on this box a GPU failure
can be a whole-box VRAM freeze. `DONE` is printed only after every case
passed and the count matched. This round only syntax-checked it (`bash -n`)
and checked its regexes against the archived sample's lines; **it has NOT
been re-executed** (the GPU was in use). The archived `results/cl5_matrix.log`
predates it.

**"Most detailed per-run logs and hashes are not in the committed summary.
Preserve full per-run evidence for the final gate."** — True of the
2026-09-04 matrix: its fifteen per-run logs lived in the session scratchpad
and only one (`cl5_sample_p1cold.log`) was archived; the summary log holds
`exit 0`, `gpu: ON`, the PASS line and (for p0/p3/p1nocache) the timing JSON
per row, but not the proof digests. The hardened runner keeps every per-run
log self-describing (`CMD:` ... `exit N`) and the evidence table, so a
re-run produces the full set. Until that re-run happens, the archived matrix
remains what the review called it: fifteen rows with `exit 0`, GPU-enabled
and ACCEPT lines, recorded by a runner that did not enforce them.

**"The reported P1-to-P3 difference should not be treated as statistically
separated from the recorded P3 spread or extrapolated to full-model proof
readiness."** — Agreed and corrected in place in §1: +6.4% on the medians
sits inside a 14.9% three-run spread. Not separated; not extrapolated.

### 5.2 What remains open

- **The hardened runner has not been re-executed.** The per-run digests,
  cache counts and identity hashes it records do not yet exist for any run.
  The next quiet-GPU slot should run it (detached, under the heavy lock,
  ~2.5 minutes for 15 cases) and archive `cl5_evidence.tsv` plus the fifteen
  per-run logs, not just the summary. Until then §1-§4 rest on the
  pre-round-7 evidence, with the limits above.
- **Cache state of the archived rows is `unknown` from the logs alone**
  (verbose was off). The cold/warm labels in §1 come from the runner's
  construction (a wiped directory vs a reused one), which the re-run will
  turn into in-log evidence.
- **P1 -> P3 at this shape is inside the noise.** Nothing here says what
  private weights cost at Mistral width.
- **The parser ranks one row** (the first eligible one) and says which
  (`ranking.ranked_row`). A median over repeats is not computed; §1's medians
  were taken by hand from the fifteen per-run `HASHLINE_TIMING` lines — nine
  of which (p0, p3, p1nocache) are in the summary log, while the six P1
  cold/warm ones were only in the scratchpad per-run logs, of which one is
  archived as `cl5_sample_p1cold.log`. The re-run makes all fifteen
  reproducible from committed evidence.

### 5.3 Proposed for files this lane does not own

- `hashline/src/bin/hashline.rs`: `pass_v3` prints `wcache::report()` (the
  `hits | misses | rejected` summary, line ~1039) but `pass_zk` (the P1/P3
  path, ~1112-1199) does not, so a ZK run's cache behaviour is visible only
  with `HL_WCACHE_VERBOSE=1`. One line — the same `if let Some(r) =
  hashline::wcache::report() { println!("  {r}"); }` — after the ZK pass's
  device-side line would put the summary on every ZK log, verbose or not,
  and the parser already reads it. CLI is Codex-owned; proposed, not edited.
