# A35: the boundary commitments made while the sealed request waits for the prover. Result: PASS by the fixed rule (a recommendation only; the switch stays OFF by default and is NOT RULED)

Date 2026-11-20 UTC. Branch `worktree-agent-addfd11fa51fe5d25`. **Base: the worktree was created at `eee3eb57` and fast-forwarded
to `perf/zk-batch-optimizations` = `f375e73d`** (`git merge --ff-only`); the source change is on top of `f375e73d`.
Labels: **MEASURED** (a run here, log in `raw/`), **DERIVED** (arithmetic on measured numbers), **CODE-READ** (file:line), **MODEL**.
Line numbers are the patched tree's.

## 1. What changed, in one paragraph

In a served stream (`stack-serve`, `serve_stream`), a request's lane thread runs the sealing pass, then
`D55Turn::sealed()` (leave the sealing turn AND wait for the prover turn), then the prove call, whose PHASE 1 makes the
`L - 1` boundary commitments while the request holds the prover. With `HL_A35_BOUNDS_AHEAD=1` (or the test arm word
`ba1`), the lane thread instead calls `seal_done()` (leave the sealing turn only) and makes the prove call at once; the
prove call runs its preflight and its PHASE 1 **unchanged** and then calls a hook, `at_prover`, that enters the prover
turn, before PHASE 2 (the forks). So PHASE 1 runs beside the previous request's forks and leaves the prover's critical
path. **No code of PHASE 1 moved or was factored**: the generator, its construction site, its domain, the loop and the
`drop(rng0)` are byte-for-byte the old text, in `prove_forks_inner`, on the same (calling) thread. Unset or `0`: today's
path (`turn.sealed()`, `planned.prove`, no hook; `turn_wait_s` = 0.0 so `total_s` is the same number). Files:
`run_fork.rs` (+F4 note, `ForkStats::turn_wait_s`, the `at_prover` parameter of `prove_forks_inner` with `None` at the
five existing call sites, `Planned::prove_at_turn`), `trained_block.rs` (`D55Turn::seal_done` / `at_prover`, the
switch `a35_bounds_ahead`, the branch in `d55_seal_and_prove`), `run_fork_tests.rs` (arm words `ba0` / `ba1`, the REQ
line's new last field "prover turn waited inside the call", two new tests). `git diff --stat`: 3 files, +213 -15.

**Deviation from the brief, and why (CODE-READ).** The brief asked to factor PHASE 1 into one function called from both
placements. That would move the `ZkRng::from_os` site out of `prove_forks_inner`, which two pinned tests forbid:
`s25_tests.rs:2963` (the two D55 sites' roles must be exactly `["prove_one", "prove_forks_inner"]`) and
`s25_tests.rs:3080-3089` (`prove_forks_inner`'s body has exactly one `ZkRng::from_os`, `&mut rng0`, and `drop(rng0);`
before `PHASE 2`). Changing their text is a stop condition. Moving the **prover turn** into the prove call instead keeps
every pinned text and the same number of construction sites (2 in `run_fork.rs`), and needs no second placement of the
generator at all.

## 2. Stage 1 answers (CODE-READ)

- **Which thread seals, where it waits, which thread runs PHASE 1.** `serve_stream` spawns `lanes` lane threads
  (`trained_block.rs:4549`); each runs `serve_one` (`:4430`), which enters the sealing turn (`seal.enter(q)`, `:4452`) and
  calls `Resident::prove_one` -> `d55_seal_and_prove` (`:3453`) **on the lane thread**. There: the sealing pass
  `seal_chain` (`:3474`, inside `prove_run_with_forks_planned`'s `seal` closure, driven on the calling thread), the
  statement, endpoints, `ForkRun::new`, `planned.check`, `StackSource::new` (`:3521`), then today `turn.sealed()`
  (`:3532`; `RequestTurns::sealed` `:4317` = mark, leave the sealing turn, `prove.enter(q)` **waits** for the prover
  turn, mark), `create_dir(run.out)` (`:3536`), `planned.prove` -> `prove_forks_inner` (`run_fork.rs:1634`), whose
  PHASE 1 (`:1660-1688`) runs on that same lane thread; `turn.proved()` (`:3556`) after the call returns.
- **Are all `l - 1` boundary planes there when the sealing pass is done?** Yes. `StackSource::boundary_plane`
  (`trained_block.rs:2361-2371`) returns `chain.outs[k]` (the sealing pass's own outputs), cloned; the source exists
  before the turn (`:3521`). PHASE 1 also needs `st.boundary_spec(k)`, `NttTables::new(st.rs.ntt_log())`, `sh.hash_tag()`
  and `fr.profile` (the generator's domain `commit_seed_domain`): all exist before the turn (`fr` at `:3514`).
- **What `PreparedBoundary` holds.** `boundary.rs:244-247`: a spec digest and an owned `CommittedZk<DevStore>`
  (zkp-core `pcs.rs:607-620`): the committed store (`cm`, with hashline's device form when the GPU made it), the host data
  (`rows x n` field words), pads, salts, mask rows; no `Clone`, consumed by `into_opening` at the join. Under A35 these
  objects are made by the same code on the same thread, owned by the same `bounds` vector in `prove_forks_inner`'s frame,
  and live from PHASE 1 to the join as before; they only exist about 0.33 s earlier (MEASURED below). Footprint peak
  unchanged at this size (46.9 against 46.8 GiB, MEASURED).
- **F4's sentence** (`run_fork.rs:519-527`): "ONE for the commit phase (the `L - 1` boundary commitments, on the calling
  thread, dropped before any fork starts)". **It stays literally true** under the change: the generator is built in
  `prove_forks_inner` on the thread that calls it (the lane thread, as before), and dropped (`:1680`) before this run's
  PHASE 2 (`:1695`); the hook is called after the drop (`:1689`). What changes is a fact F4 does not state: in a stream
  the commit phase now runs while the previous request's forks run, i.e. outside this request's prover turn (with
  `HL_D55_AHEAD` on, this request's own before-challenge parts already ran before PHASE 1 today; A35 does not change
  that). The note added at `run_fork.rs:529-540` describes both placements and says NOT RULED, default off.
- **Tests that pin the number or text of `ZkRng::from_os` sites.** `s25_tests.rs:2859-2900` (the production census: 9
  sites, 2 in `run_fork.rs`), `:2936-2967` (the D55 sites and their enclosing functions), `:3073-3092` (the body of
  `prove_forks_inner`: one `from_os`, `&mut rng0`, no clone, `from_os` < `drop(rng0);` < `PHASE 2`; `ForkCtx` carries no
  `ZkRng`), `:3103-3110` (the `ZkRng` struct text, no consumption accessor), `:2918` and `s26_tests.rs` (`boundary.rs` makes
  no generator; every production generator from a domain builder). All pass unchanged (gate G4).
- **Stop rule check.** No edit in `zkp-core` (`pcs.rs`, `metal.rs`) or any forbidden file; PHASE 1's code and every
  absorb are untouched, so no committed word, transcript absorb or receipt byte can change under a seeded generator
  (confirmed by G3); no existing pinned test's text was changed (only new tests, the arm parser and the REQ line's tail
  in the ignored A/B harness).

## 3. Gates (each through the resource guard, one at a time; guard run ids from `raw/*.guard.json`)

`W` = `ops/zkp-mvp/gpu-metal/hashline`; binary `hashline-ee9e07880f531987` (sha256 `092590a2...0da644`). Cargo: `/opt/homebrew/bin/cargo` (no rustup toolchain on this Mac, as A33).

| gate | leaf | guard run id | result |
|---|---|---|---|
| G1 build, attempt 1 | `cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path W/Cargo.toml --lib --no-run` | `1f70538f6ef0` | exit 101: one type error in the NEW test (`Vec<usize>` for `u64` sizes); log overwritten by attempt 2 |
| G1 build, attempt 2 (fix round 1) | same | `3a1fdd63c743` | exit 0, 169 s, peak 4.48 GiB; no new warning in the changed files |
| G1 no-feature | `cargo check --tests --offline --locked -j 2 --manifest-path W/Cargo.toml` | `4f9f3aa2cbe3` | exit 0, 15 s |
| G3 seeded equality, CPU | `a35_the_commit_phase_before_the_prover_turn_gives_the_same_words` | `373b800c0fec` | 1 passed (41 s) |
| G3 seeded equality, Metal | `..._on_the_device` (ignored, by name, class gpu, `HL_GPU_REQUIRED=1`) | `c9f5da44bac7` | 1 passed (10 s) |
| G4 census and s25 | `private_block::s25_tests::` | `c93d10915ee5` | 20 passed (incl. the generator census and W-8(5)) |
| G4 s26 | `private_block::s26_tests::` | `e23fcf408411` | 8 passed |
| G4 A22 stream tests (CPU) | `run::fork::tests::a22::` | `c09ac2529f70` | 4 passed, 5 ignored |
| G2 full suite | all non-ignored, `--test-threads=8` | `4bcc8b82eaf8` | **1004 passed, 3 failed, 135 ignored** (638 s) |
| G2 the three failures | the three by name | `fd19c297b750` | 3 of 3 fail |

**G2 = A33's G2**: the three failures are exactly A33's named three (`review_tests::a_toy_receipt_made_before_f12_is_refused`,
`accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`,
`trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`), which fail on the unpatched
tree too (A33 section 7). A33 had 1003 passed / 134 ignored; +1 passed and +1 ignored are the two new tests. I did not re-run them
on an unpatched binary here.

**What G3 checks.** The resident synthetic W16R2 rung stack (L = 4) served with seeded generators (`SeededForks`, A18's seed),
at (window, lanes) = (0,2), (2,2), (0,1) on the CPU and (0,2), (2,2) on Metal, each with the switch off and then on; requests
honest, lie at layer 1, honest, honest. In every one: the three receipts verify from their run directories by a fresh
verifier; each head equals the replayed commit phase **byte for byte**; each interior fork equals that fork proved whole **byte
for byte**; the lie is refused before the run header and leaves nothing; the turns keep request order. Across the switch: the
boundary roots of all 18 (CPU) / 12 (Metal) proved requests are byte-identical, and the receipt sizes are equal. The clocks show
the placement: off, the commit phase is inside the prover turn (`at[4] - at[3] >= commit`) and the call waited 0.0 s inside;
on, it lies between the sealing side and the prover turn (`at[3] - at[2] >= commit`). **What it cannot show:** two whole
receipts byte-equal, because a request's endpoint commitments are drawn from the operating system (`prepare_endpoints`,
`endpoint_g.rs:269`) and have no seeded form; adding one would touch the endpoint code and the census. Every word the seeded
generators fix is compared.

## 4. Measurement (stage 4; rule fixed before the run, unchanged)

One guarded GPU job, one process, `raw/t1.log`, guard run `5dee3dc2932b` (421 s, peak RSS 33.4 GiB, peak VRAM 22.5 GiB, exit 0).
Arms `serve8+lanes2` and `serve8+lanes2+ba1`, `HL_A22_AB_PASSES=6`, `HL_D55_AB_ALTERNATE=1`, the rest of `run_l2.py`'s
environment (`run_a35.py`). Before: guard status no job, heavy lock free; `pgrep -fl ds4-bench` none; load average 22.8
(`raw/t1.status_pre.txt`). After: ds4-bench none, load 23.1, binary hash unchanged. **The box was not quiesced** (load ~22 from
non-guarded processes before and after); the two arms alternate inside one process, so the pairs share the conditions. Every
receipt of pass 0 of both arms verified (818,728,672 B each). One timing run; no repeat.

**Steady gap per pass, (result[6] - result[1]) / 5, s. MEASURED.**

| arm | p0 | p1 | p2 | p3 | p4 | p5 | median |
|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.732 | 3.787 | 3.730 | 3.779 | 3.809 | 3.747 | 3.763 |
| serve8+lanes2+ba1 | 3.538 | 3.606 | 3.563 | 3.582 | 3.541 | 3.582 | 3.572 |
| difference | -0.194 | -0.181 | -0.168 | -0.197 | -0.269 | -0.165 | **-0.187 s, -4.98 %** |

**Verdict by the fixed rule: PASS** (lower in 6 of 6 passes, median -4.98 % against the 3 % bar). DERIVED: steady
throughput 34.0 -> 35.8 tok/s at T = 128 (x1.053); the harness's own SUMMARY: steady mean 34.19 -> 36.39 tok/s. Cadence
(result[7] - result[0]) / 7, for reference: 3.745 -> 3.513 s, -0.225 s (-6.06 %), 6 of 6.

**Per request, medians over the 6 passes of q1..q6, s. MEASURED** (full per-index tables in `A35_TERMS_t1.md`):

| term | off | on | on - off |
|---|---|---|---|
| prover hold (prover left - entered): the pacing term | 3.784 | 3.533 | **-0.251** |
| prove call (its own seconds; the turn wait excluded) | 3.784 | 3.873 | +0.089 |
| of which commit phase | 0.214 | 0.331 | +0.117 (now beside the previous request's forks) |
| of which forks | 3.484 | 3.458 | -0.026 |
| of which join | 0.078 | 0.074 | -0.004 |
| prover wait (entered - sealing side done) | 0.461 | 0.347 | -0.114 (on: includes preflight + commit) |
| prover-turn wait inside the call | 0 | 0.018 | |
| sealing pass (beside a proof) | 3.064 | 2.974 | -0.090 |
| receipt write | 0.216 | 0.221 | +0.005 |
| footprint peak median / max, GiB | 46.9 / 47.1 | 46.8 / 47.2 | ~0 |
| process CPU per pass (user+sys) | 487.4 | 488.0 | +0.6 |

Reading (DERIVED from the table): the commit phase leaves the prover hold (-0.25 s, a bit more than the 0.21 s it took there),
and takes 0.33 s instead of 0.21 s beside the previous request's forks, where it is hidden. Request 1 is the exception
(commit 0.565 s, inside-call wait 0.281 s: its commit phase overlaps the first, cold-start part of request 0's call). The
inside-call wait in steady state is only 0.018 s (median): **the commit phase now finishes just before the previous prover
ends, so the slack that A33 measured (0.46 s of prover wait) is nearly used up**; a further host move out of the prover turn
would gain little unless the sealing side gets shorter. The ceiling stated in the brief (0.22 s, 5.8 %) was reached
(-0.187 s steady gap, -0.225 s cadence, -0.251 s prover hold).

## 5. What was not verified

- Whole-receipt byte equality across the switch (impossible without a seeded endpoint path; see section 3).
- The two new tests on an unpatched binary (they need the new switch); the suite's three failures were not re-run on an unpatched
  binary here (A33 did).
- No repeat timing run; the box was not quiesced (load ~22). No GPU trace. Not measured at other lane counts, at `HL_D55_AHEAD > 0`
  (the window plus A35 together), or on `stack-serve` with the trained 8B export (only the synthetic 8B stack).
- `stack-prove` (no turns) never reads the switch (`run.turn.is_some() && ...`, `trained_block.rs:3527`); not separately timed.
- A request refused in its preflight or PHASE 1 under A35 now fails before entering the prover turn (it calls `proved()`, which
  leaves a turn it never entered: the "did not need it" case of `Turn::leave`, as a refused request's drop does today) and its run
  directory exists while it waits; G3's refusal is a sealing-pass one, so this path is CODE-READ only.

## 6. Decisions needed

1. **A ruling on the placement** (owner): F4's words hold literally, but "the commit phase runs while the previous request's forks
   run, outside this request's prover turn" is new and is not in F4 or D55; the Lean statements and the soundness note do not
   model the stream's turns, as far as I read, but I did not check `formal/`. The switch stays off until then.
2. Whether the order "run directory created, then wait for the prover" (under A35) is acceptable; the comment at
   `trained_block.rs:3522-3527` says so. Keeping the old order would need the hook to create the directory and a refusal path that
   does not remove an existing directory; not done.

## 7. Files

`gates.py` (the gate sequence; groups build / check / focus / device / suite), `guarded.py` (A33's), `run_a35.py` (the timing
job, from `run_l2.py`), `a35_terms.py` (the steady gap, the rule and the per-index terms, from `l2_steady.py` / `l2_terms.py`),
`A35_TERMS_t1.md` (its output), `raw/` (every leaf's log, guard record, status before and after, `.done` markers).
