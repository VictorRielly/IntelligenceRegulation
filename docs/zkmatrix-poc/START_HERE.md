# START HERE — the proof project in plain words

Status: LIVE. Written 2026-09-01 (orchestrator, Claude) so that ANY
person or agent with no prior contact with this repository can
understand what is being built, where it stands, why the speed goal
is hard, and what the choices are. Every number carries a label:
[MEASURED] = a run happened on a named machine; [COUNTED] = derived
from measured pieces by arithmetic; [MODEL] = an estimate with stated
assumptions; [EXTERNAL] = someone else's claim, unverified. If this
page and a ledger disagree, the ledger is newer (see §9).

Read this page first. Then, if you are going to do work, read §8
(how to work here) and the task board (§9).

---

## 1. What the project does

We are building a program that produces a **cryptographic proof that
a specific language model was really run on a given input**. The
proof lets anyone check, with a small program and without the
model's weights, that the output came from exactly those weights on
exactly that input. Two properties are non-negotiable:

- **Exactness.** The model is first converted to 8-bit integer
  arithmetic (a step called *calibration*, done once per model). The
  proof is then about that integer computation bit for bit, so the
  same proof means the same thing on any hardware. A model that has
  not been calibrated cannot be proven at all; that is a feature.
- **Zero knowledge.** The weights (and, in some modes, the
  activations) stay hidden. The math is lattice-based, which is also
  believed to resist quantum computers.

The engine is Rust, in `zkmatrix-rs/`; one binary, `ring_matmul`,
with many sub-commands. Python in `scripts/` does calibration and
export. `tests/` holds the Python test suite. `docs/zkmatrix-poc/`
holds the design memos and the task board. Ledgers named
`PROGRESS_*.md` at the repository root record every result.

## 2. The one number that matters: seconds per proof

The written contract (`docs/zkmatrix-poc/TARGET_CONTRACT.md`) defines
the headline as: **5-15 seconds, p95 over at least 20 warm runs, on
one consumer GPU of at most 450 W, on an otherwise idle machine**, for
one proof of the **feed-forward blocks** of a 7-8B-parameter model
over a **512-token window** (32 blocks, width 4096, hidden 11008 in
the contract's surrogate; 14336 for the real Mistral-7B used since).

Plain reading: "a proof" today means the feed-forward half of every
transformer layer, for one 512-token prefill. The attention half is
designed and proven at toy scale (§4) but is **not** in the 8B proof
yet. Any write-up must say "FFN-only" until it is.

**The goal as restated by Victor on 2026-09-02: at least 50 proven
tokens per second for a 30B-class model on ONE GPU** (a very large
GPU such as an H100 is allowed). This is "the competition to beat":
a vendor (Attestable, 2026-08-11) claims Gemma-4-31B at 53 tokens/s
(batch 1) and 77 tokens/s (batch 4) on one H100, with 4-8 MB proofs
and sub-second verification [EXTERNAL, VENDOR-CLAIMED, no paper or
code]. In the units this repository measures: one decoded token at
30B costs about 3.1e10 multiply-accumulates, so 50 tokens/s means
about 1.55e12 proven MAC/s. Our measured rate is 1.4e9 on the
laptop's 55-70 W GPU [MEASURED]. The honest conversion is
`U_PERF3_THROUGHPUT_MODEL.md` (2026-09-02; every number sourced,
the hardware factor as a range). Its answer: the built system is a
~0.6-0.8 tokens/s system at 8B for 512-token prefill on the laptop,
and ~0.0025 tokens/s for one-token-at-a-time decode, because every
proof re-proves the whole weight side [MODEL from the one measured
pass]. The recorded design path (the two-tier opening with the
weights preprocessed, §5) at its own modelled constants reaches
**2-15 tokens/s at 30B prefill on one H100** and under 1 tokens/s
for decode [MODEL on MODEL]. **Under no assumption recorded in this
repository does the lattice line reach 50 tokens/s at 30B on one
GPU.** The one measurement that could have moved that answer up is
now in (lane QQ, 2026-09-02): with the weights preprocessed once
per model, the two-tier opening proves the real 12x512 weight group
in 2.08 s per proof against 2.09 s for the built opening on the
laptop GPU — parity, not the 5x the design needed [MEASURED]. Its
8B projection is 2.8-3.4x over built for the weight side [MODEL], so
the lattice line sits at the low band of the model (about 0.5-3
tokens/s at 30B prefill on one H100). A further design change
("Variant B", counted at 8-15x, not built) would need a ruling. The
remaining open question nobody has priced is whether any
lattice-line activation-side opening can prove ~1e12 MAC/s on one
board (the memo's U2). That question is what choice D in §7 is
about — and choice D now has a measured first row (lane UU,
2026-09-02): a hash-based prototype proves the identical 12x512
statement in 23.0 s on the laptop's CPU alone, parity with the
lattice line's GPU-assisted 21.0 s, with 4.3x less memory, 44x
larger proofs, and without zero knowledge (see §6). Its GPU port and
its own tokens-per-second model are round 11's follow-on lanes.

## 3. Where we stand (the honest numbers)

### 3.1 What has been measured

| shape | machine | wall | notes | label |
|---|---|---:|---|---|
| 125M model, 12 layers x 512 tokens, the full statement | WSL laptop: Core Ultra 9 185H, 8 threads + RTX 4070 Laptop GPU (55-70 W) | **21.0 s** (commit 2.5 / prove 15.5 / verify 1.7), 6.7 GB RAM, proof 1.5 MB, 20/20 accept | the reference number, 2026-08-18; the same shape was 4,811 s on one Mac thread in July | [MEASURED, QUIET] |
| same, CPU only | same box | 81.5 s | | [MEASURED] |
| 125M, 12 x 128 | same box, GPU | 10.5 s | | [MEASURED] |
| one 8B-width layer, 16 tokens | WSL laptop | **out of memory at 15 GB** | the box cannot hold 8B; the Mac (256 GB) can | [MEASURED] |
| **any 8B proof end to end** | — | **never run** | queued on the Mac as tasks T15-T17 (§7) | — |

### 3.2 What the 8B proof is expected to cost with today's protocol

The 8B feed-forward pass is about 100x the work of the 125M rig
(2.9e12 multiply-accumulates vs 2.9e10). Scaling the measured 21 s
by the counted growth of each phase:

| machine | expected 8B wall | label |
|---|---:|---|
| the WSL laptop GPU (if it had the memory) | ~11-16 min | [MODEL] |
| one desktop GPU board (4-6x the laptop part, never measured) | ~2-4 min | [MODEL] |
| the Mac, CPU only, 16 tokens | ~15-30 min | [MODEL] |
| the Mac, CPU only, 512 tokens | ~35-75 min | [MODEL] |

Memory at 8B: the 512-token pass peaks around **72 GB** in the
cheaper "range-only" proof mode [COUNTED, 2026-08-31], which fits the
Mac. The "full" mode (every lookup routed through the new aggregate
checks) needs an encoding change first (§7, item E).

### 3.3 The gap to the goal, in one line

Today's engine proves **1.4e9 int8 multiply-accumulates per second**
on the laptop [MEASURED]. The contract needs **1.9-5.8e11**. That is
140-420x on the laptop part, or **roughly 10-50x on a desktop board**
[MODEL]. The GPU kernels are already running at 70-88% of their
arithmetic ceiling (measured 2026-08-18), so this gap is in the
**shape of the protocol**, not in tuning.

## 4. What is finished (so you do not redo it)

- **The engine proves real models exactly.** Every optimization since
  July is "differential": the proof bytes are byte-identical to the
  frozen reference, checked by batteries at every commit.
- **Calibration of real 7-13B checkpoints works.** Mistral-7B and
  Gemma-4-12B convert to the exact int8 statement with quality loss
  of +0.216 and +0.035 nats respectively [MEASURED], using the
  "widened stack" (16-bit resolution at a few named sites). The
  first 7B attempt lost +8.18 nats; finding and fixing that took the
  second half of August.
- **The multi-layer statement is bound.** Layers are chained by
  proven seams (the output of layer l is proven to be the input of
  layer l+1). Honest label: the current chain is an **FFN tower**;
  the real edge between layers (residual add, attention, RMSNorm) is
  replaced by a declared seam until attention lands.
- **Memory diets landed.** Peak RSS is down 46-47% since round 5;
  the 8B pass fits 128 GB [COUNTED].
- **Attention is designed and proven at toy scale.** The integer
  softmax chain (spike X-S1), the 66-entry typed attention layer
  (X1), and the 125M attention calibration table (X2, 2026-09-01)
  are done. Next is X3: one full attention layer proven at 125M.
- **"Stage A"** (replacing ten expensive lookup sub-proofs with cheap
  aggregate checks) is **in the engine behind a switch**: proof bytes
  2.15x smaller; wall not faster on CPU (+15% at 125M, where the
  lookups were cheap anyway); its memory win only shows at 8B.

## 5. Why the speed goal is hard (plain explanation)

A proof has three parts:

1. **Commit**: bind every number (weights, activations, helper
   values) into a short cryptographic commitment.
2. **The arithmetic checks**: show the matmuls, the SiLU table
   lookups, the rounding steps and the range facts all hold.
3. **The opening**: convince the verifier that the numbers used in
   step 2 are the committed ones.

Step 3 is the floor. Today's opening walks the **entire witness**
(about 500 million "digit rings" at 8B), and **71% of that witness is
the weights, which never change between proofs**. The opening's
cost grows 41-43x from the 125M rig to 8B [COUNTED], and it is the
part that scales worst. Everything above it (steps 1 and 2) has
been optimized to its ceiling on this hardware.

The literature's answer is a **two-tier ("square-root") opening**:
split the witness into blocks, commit each block, and run the
expensive lattice argument only on a square-root-sized summary. With
that structure the weight side can be **preprocessed once per model**
so that each proof only pays for the activations. The design memo
(`U_PERF3_HEADLINE_ROUTES.md`) models this composition at **~20-40 s
on one desktop board and ~6-13 s on four boards** [MODEL]. That is
the only path on the lattice line that reaches the goal, and it
requires desktop hardware too.

## 6. What was tried against the gap, and the verdicts

| attempt | result | verdict | where |
|---|---|---|---|
| GPU + AVX2 kernel campaign (Aug 17-18, 9 rounds) | 12x512: 155.6 s -> 21.0 s | kernel curve flattened; residual is structural | `PROGRESS_UPERF2.md` |
| Stage A in the real pass (lane GG, Aug 28) | bytes 2.15x smaller, wall par on CPU, full mode OOM at 15 GB | landed behind a switch | `PROGRESS_UPERF3.md` Agent GG |
| **Stage A's checks on the GPU (lane RR, Sep 2)** | the aggregate check 8.6-10x faster on the device, bit-identical; but Stage A's total wall only reaches parity with the old path (never faster at 125M) and only with a batched claim transport that needs a ruling; memory 7.5 -> 3.1 GB | landed; buys bytes and memory, not speed | `results/uperf3_rr_stage_a_gpu.md` |
| **Two-tier opening + preprocessed weights on the GPU (lane QQ, Sep 2)** | per-proof weight-side opening 2.08 s vs 2.09 s built at 12x512: parity, bar was 5x; 8B projection ~3x | the decisive lever measured; "Variant B" (8-15x on paper) needs a ruling | `PROGRESS_UPERF3.md` Agent QQ |
| **Full-mode memory encoding (lane SS, Sep 2)** | 12x128 full mode 8.1 GB (was OOM); the memo's route was wrong (32x worse), a compact helper works; 8B full-mode >= 78 GB | landed; ruling on the helper as the encoding | `PROGRESS_UPERF3.md` Agent SS |
| **Throughput model (lane TT, Sep 2)** | every tokens/s number sourced; lattice line 2-15 tok/s at 30B prefill on one H100 at best, <1 decode; the Aug 30 board line retracted | the yardstick for all decisions | `U_PERF3_THROUGHPUT_MODEL.md` |
| **The hash-based comparison prototype (lane UU, Sep 2)** | a NEW crate `hashline/` proves the identical 12x512 int8 statement (all 12 layer digests reproduced) in **23.0 s on the laptop CPU alone** vs the lattice line's 21.0 s with the GPU and 81.5 s CPU-only; 1.26e9 proven MAC/s; 1.56 GB memory (vs 6.7); 66.8 MB proofs (vs 1.5 MB); verify 2.8 s; seven tamper tests reject; NOT zero-knowledge; hash-only ~100-bit | one untuned lane-day reached parity with three weeks of lattice kernel work; its GPU port is estimated at 1.5-2.5 s per pass [MODEL] | `results/hashline_pass_12x512.md`, `PROVING_CHANNEL_OPTIONS.md` §3 |
| **Spike S4: the two-tier opening on the real rig** (lane FF, Aug 27-28) | correctness bit-for-bit OK at 4M rings; **speed 1.10x vs the 5x bar**; verifier 3.9 s vs sub-second | NO-GO on speed; cause: the "cheap" linear pass computes general ring products | Agent FF |
| Redesign of S4 on paper (lane II, Aug 28) | best composed case **1.6-2.5x** | **"the 5-15 s question on this line is CLOSED unless a structurally new idea arrives"** | `U_PERF3_S4_REDESIGN.md` |
| Fallback posture (Aug 28 ruling) | Stage A + one-point front end + a desktop board | **~100-160 s per proof on one board** [MODEL] | task board §0 |

Two things the closed verdict did NOT count, stated in its own
honesty section: multi-threading of the redesigned pass, and running
the linear pass as GPU scalar kernels rather than CPU ring products.
The bar it failed was set at one CPU thread on a synthetic shape.
Whether the same design clears the bar on a GPU at the 8B weight
shape is an open, countable question (§7, option A).

Separately, a different proof system exists in the market: the
hash-based "float/int-mix" line (Attestable-class). Vendor claims put
it near 1.6e12 proven MAC/s on one H100 [EXTERNAL, unverified], about
1,000x our measured rate. It trades our exact-integer, lattice-based
guarantees for hash-based ones with an approximation contract for the
nonlinear parts. It is documented, not started
(`PROVING_CHANNEL_OPTIONS.md`); the standing ruling (Aug 18) was to
finish the lattice-line 8B MVP first.

## 7. The choices, and what was decided (2026-09-02: ROUND 10 CLOSED, ROUND 11 OPENED)

Round 10's four lanes all landed the same day (§6 table). Victor then
ruled (console, 2026-09-02): start the hash-based comparison
prototype now (round 11 lane UU, a new crate `hashline/` proving the
same 12x512 int8 statement with a hash-based small-field stack; its
deliverable is a measured row next to the lattice line's 1.4e9
MAC/s); adopt the compact full-mode helper and the batched claim
transport as the Stage-A forms (lane WW makes them the defaults and
gets the reference shape running on the laptop); and build "Variant
B" of the two-tier opening as a separate attempt (lane VV, against
the original 5x bar). Choice C (hardware) remains open. The
paragraph below is the round-10 record.

Victor chose the recommended order on 2026-09-02. Round 10 in
`PROGRESS_UPERF3.md` opens four lanes with self-contained briefs:
**QQ** = choice A plus the never-tested weight preprocessing (the
two-tier opening counted and measured on the GPU cost model, then
the per-model / per-proof split measured); **RR** = choice B (Stage
A's checks on the GPU, replacing the unsourced 1.2-1.5x with a
measurement); **SS** = choice E's laptop half (the memory encoding
rungs V1-V4); **TT** = the tokens-per-second model that the new goal
is stated in. Choice E's Mac half is `MAC_RUNBOOK.md` (Victor pulls
and runs). Choice C (hardware) is Victor's; choice D (the hash-based
prototype) is decided after QQ's count lands. The original five
choices, for the record:

- **A. Reopen the two-tier opening on the GPU cost model.** Count,
  then measure on the laptop's RTX 4070: the redesign's factored
  linear pass as a scalar integer GPU kernel over the weight group,
  the lattice recursion at square-root size; acceptance = the served
  claims bit-identical to the built opening (the S4 legs) and the
  8B-projected opening wall in seconds. ~1-2 weeks on the WSL box.
  This is the test of whether the "20-40 s per board" row is real.
  If it fails, the lattice line's 5-15 s answer is "multi-board or
  not at all".
- **B. Port Stage A's aggregate checks to the GPU.** The safe
  1.2-1.5x [MODEL]; measurable at 12x512 on the WSL box; no design
  ruling needed. ~1 week.
- **C. Get desktop-class hardware under the ladder.** Every 8B clock
  above assumes a 4-6x board factor that has never been measured.
  One 4090/5090-class board, or a rented H100 block, turns [MODEL]
  rows into [MEASURED] ones. Purchase/rental is Victor's call.
- **D. Start the hash-based comparison prototype in parallel.** Same
  int8 statement, the 125M 12x512 rig, in an open sumcheck/GKR
  framework, measured on our GPU (~1-2 lane-weeks [ASSUMED]). This is
  the fastest route to 5-15 s IF the vendor claims hold, and it is a
  product decision (assumption class changes).
- **E. Keep the 8B MVP moving regardless.** Mac queue T15 -> T16 ->
  T17 (the first real 8B proof numbers; Victor/Grok run these), and
  the round-9 memory item on WSL (the compact committed-h encoding,
  rungs V1-V4 in `U_PERF3_COMMITTED_H.md`) so the 8B pass fits in
  "full" mode. Also X3 (one attention layer at 125M) toward a proof
  that covers whole layers.

Recommended order if speed is the priority: A and B in parallel on
the WSL box now (they touch different files), C as soon as hardware
is available, E on the Mac in the background, D decided after A's
count (one week in) so the decision is made with a number.

## 8. How to work here (the rules that keep results trustworthy)

Full rules: `TASK_BOARD.md` §1-2 and `CLAUDE.md`. The short version:

- **Two machines.** The WSL laptop (22 threads, 15 GB, RTX 4070
  Laptop; the contract's reference CPU box) and the Mac (M3 Ultra,
  256 GB; runs the 8B shapes and the full test suite). Label every
  timing `[WSL-BOX]` or `[MAC-BOX]`, `1T` or `NT`, `QUIET` or
  `NOISY-SHARED`.
- **Build**: `cargo build --release` inside `zkmatrix-rs/`
  (plain cargo; never prefix `PATH=`).
- **The differential floor.** A speedup is accepted only if the
  proof bytes are byte-identical to the reference: the function
  battery (`ring_matmul uperf-pc diff-battery`), the freeze rows
  (`ring_matmul freeze-check`, exit 0; on WSL it panics at the last
  rows for lack of the Mac export, which is expected), and the
  EVAL-PROOF DIGEST printed by `uperf-pc pass-profile` unchanged at
  the same shape. A speedup that moves any digest is a bug.
- **Transcript-preserving only.** Do not change what the transcript
  absorbs, RNG draw order, planner parameters, or freeze rows without
  a ruling from Victor recorded in the ledger.
- **Do not touch**: `codex-audit-*`, `scripts/logup_*_spike.py`,
  `src/manifest.rs`, and the kfield/sumcheck/gkr internals named in
  the board's rule 5.
- **Lanes and ownership.** Parallel work happens in sibling
  worktrees `../wt-uperf3-<lane>` on branches `uperf3-<lane>`; each
  lane brief in the ledger has an `OWNS:` block naming the only files
  it may write; everything else is read-only for that lane.
- **Heavy runs are detached** (`setsid nohup ... flock
  /tmp/zk-heavy.lock ...` with a `.done` marker; see `CLAUDE.md`), one
  heavy job at a time on the 15 GB box, and the 125M export is
  selected with `M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl`.
- **Record everything** in your lane's status section of the current
  ledger (`PROGRESS_UPERF3.md`): date + box + label, the exact
  command, the verdict with numbers, the commit hash. Commit prefix
  `U-PERF3 <LANE>:`.

## 9. Where things are (the map)

| what | where |
|---|---|
| the ordered task queue and the always-current handoff state | `docs/zkmatrix-poc/TASK_BOARD.md` (§0 first) |
| the current ledger (rounds 1-9 of tranche U-PERF3, one status section per lane) | `PROGRESS_UPERF3.md` |
| the previous ledgers (the kernel campaign; Phase 0) | `PROGRESS_UPERF2.md`, `PROGRESS_UPERF.md` |
| the phase plan | `docs/zkmatrix-poc/CONTINUATION.md` |
| what the goal means, exactly | `docs/zkmatrix-poc/TARGET_CONTRACT.md` |
| why the gap exists and the candidate levers, with counts | `docs/zkmatrix-poc/U_PERF3_HEADLINE_ROUTES.md` |
| the Stage A design | `docs/zkmatrix-poc/U_PERF3_OPENING_LAYER_DESIGN.md` |
| the two-tier spike verdict and its redesign | `docs/zkmatrix-poc/U_PERF3_S4_REDESIGN.md` (+ Agent FF in the ledger) |
| the lattice line vs the hash-based line | `docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md` |
| the 8B scaling model and the memory arithmetic | `docs/zkmatrix-poc/U_PERF3_MVP8B_SCALING.md` |
| the calibration story (why 7B first failed, what fixed it) | `docs/zkmatrix-poc/U_PERF3_QUANTIZATION_MEASUREMENTS.md` |
| the attention design | `docs/zkmatrix-poc/U_PERF3_ATTENTION_STATEMENT_DESIGN.md` |
| the open memory item | `docs/zkmatrix-poc/U_PERF3_COMMITTED_H.md` |

## 10. Glossary (terms you will meet in the ledgers)

- **Witness**: all the numbers the proof is about (weights,
  activations, intermediate values). **Digit ring**: the unit the
  lattice commitment works on; the 8B witness is ~500M of them.
- **Commit / commitment**: the short binding value computed from the
  witness. **Opening / eval proof**: the argument that committed
  values are the ones used. **Group**: the witness is committed as a
  weight group and an activation group, one opening each.
- **Descent**: the older, expensive sub-proof for a table lookup or
  a range fact. **Stage A**: their replacement by aggregate checks.
- **Range fact**: a proven statement that a value fits in a given
  number of bits; the mechanism by which an uncalibrated model fails
  to prove.
- **Two-tier / sqrt opening**: the block-structured opening of §5.
  **S4 / S5**: the spikes that test it. **Spike**: a time-boxed
  experiment with pre-registered acceptance criteria.
- **12x512, 32x16, 3x16**: layers x tokens of a proof shape. The
  125M rig is 12 layers wide 768; 8B is 32 layers wide 4096.
- **Calibration / export**: converting a float checkpoint into the
  exact int8 statement plus the files the engine reads.
- **Freeze row / freeze-check / diff-battery / EVAL-PROOF DIGEST**:
  the byte-identity gates of §8.
- **Lane / worktree / tranche / round**: a unit of parallel agent
  work; its files; the campaign it belongs to; one batch of lanes.
- **Composed statement / tower / seam**: the multi-layer proof; its
  honest label while attention is absent; the proven layer-to-layer
  link.
- **Grok / the Mac queue**: a second agent (Cursor/Grok) runs the
  ordered task list on the Mac when Claude is unavailable; task ids
  T1-T17 live on the board.
