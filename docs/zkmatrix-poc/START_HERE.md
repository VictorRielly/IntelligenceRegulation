# START HERE — the proof project in plain words

**Latest, 2026-09-19:** the GPU opening optimization passes independent
device checks and all twelve CPU/GPU proof-byte gates; native freeze passes.
Its local kernel gain is measured, but its 0.8–1.8-second full-pass saving
remains an estimate. [Integration review](ZK60_FSP_L9_INTEGRATION_20260919.md).
The full Python run covered 1,140 tests (61 skipped); its one lock-related
error is resolved by a test-isolation fix and an 18-test targeted rerun.
Under the new D13 ruling, the
first MVP proves hidden model blocks; token generation follows. Model-scale
private-block coverage and five-second proving remain open.

**Current integration, 2026-09-19:** the native attention and complete tiny
block are now in the main worktree, with tests and independent receipt
verification passing. [Integration and measurements](ZK60_ATTENTION_INTEGRATION_20260919.md).
Whole-proof privacy and five-second model-scale proving remain open.

**Capture prerequisite completed:** two receipts per native profile now have
complete verifier recordings, reproduced in fresh processes with tampering
controls. [Format, evidence and remaining privacy review](ZK60_NATIVE_CAPTURE.md).

**Corrected model-scale baseline:** the retained lane-AL public-IO FFN-only
Mistral-7B run proves in **58.40 s**, verifies in 1.08 s, and produces
1,234,936,956 bytes after the host fix [MEASURED, NOISY-SHARED, 2026-09-04].
That is 11.7× the five-second target for the proving phase; witness load+chain
adds 134.50 s and total recorded wall is 196.79 s. It supersedes the earlier
95-second lane-AH headline; older rows below retain their historical values.
[Retained log](../../results/hashline_convert_r3.log),
[current speed plan](ZK60_FIVE_SECOND_PLAN.md).

**Current work, 2026-09-18:** [continuous MVP loop](ZK60_MVP_LOOP_20260918.md).
The complete fixed block has a **785-byte Groth16 receipt**, independent
verification and eight rejection controls. The full Python suite passes
(962 tests, 60 skipped); native freeze passes with the existing WSL fixture.
The [runner](ZK60_ZKVM_DEMO.md) now supports explicit block/token profiles
and trusted image pins (52 tests). The two-block token kernel has 19 passing
tests; its guest/host has 24 passing tests and actual zkVM execution, and its
real proof is running. [Codex/Fable coordination](ZK60_CODEX_FABLE_COORDINATION.md)
splits functional integration from the requested custom attention delivery.
D7 profile/model approval, custom whole-proof privacy, model-scale completion
and the five-second target remain open.

**Rulings live in [the decisions register](ZK60_DECISIONS.md)** (2026-09-18):
two lines (zkVM intermediate for the first complete private tiny block; the
custom prover for the throughput target), about 97 bits conjectured accepted
for the intermediate, the Groth16 trusted setup accepted, Groth16 receipts
only, and the pending rulings. Read it before quoting any security number.

**Current work, 2026-09-15:** [MVP refresh and results](ZK60_MVP_20260915.md).
The [one-command component demo](ZK60_P1_DEMO.md) passes real proof generation,
independent verification and six rejection controls. Fable 5.1's bounded
privacy diagnostic and Opus 5's demo are integrated with
[Codex's qualifications](ZK60_MVP_REVIEW.md). A complete private block and
whole-proof privacy remain open. The dated measurements below describe their
original scope and profiles.

**Required privacy (Victor, reaffirmed 2026-09-09):** the first PoC hides
**inputs, outputs and intermediate activations**, with public weights allowed
(P1). The full version also hides **model weights** (P3).
This scope is decided. [Privacy requirements](ZK60_PRIVACY_REQUIREMENTS.md)
records the existing decision separately from current implementation status.

**Privacy correction, 2026-09-08:** the legacy hash-line FFN `--zk` / `--p3`
proofs have demonstrated private-value disclosure in synthetic fixtures.
Their verification and frozen performance results do not establish zero
knowledge. [Round 16](ZK60_ROUND16.md) adds an executable paired-mask FFN
prototype in both privacy modes. [Round 17](ZK60_ROUND17.md) adds bounded saved
proofs and separate-process verification, plus Opus's joint linear analysis.
[Round 18](ZK60_ROUND18.md) adds input/output binding with a consuming owner and
one eight-slot mask commitment following O6; all CPU checks pass.
[Round 19](ZK60_ROUND19.md) integrates O7 and captures/replays the complete
IO observation set with saved receipts; joint IO privacy analysis is next.
[Round 20](ZK60_ROUND20.md) checks the PCS pads/columns and shared mask opening
with a conditional algebraic construction on those captures. O8's joint
message/alias result and the adaptive transcript argument remain pending.
[Round 21](ZK60_ROUND21.md) confirms the existing private-IO requirements in
git history and checks both IO sumcheck mask channels on real captures.
[Round 22](ZK60_ROUND22.md) completes the interrupted round-21 commit and
integrates O8 with a strict analysis gate and freshly captured IO evidence.
O8 is delivered; caller-fixed endpoint and adaptive/repeated-proof simulation
remain open. The old temporary capture bytes are unavailable in this session.
[Round 23](ZK60_ROUND23.md) checks the two fresh proofs per mode jointly and
adds a research-only endpoint preparation simulator for the ideal hash oracle.
It corrects the earlier assumption that salted leaves and Merkle nodes have
separate hash domains. This is bounded analysis, not full privacy acceptance.
[Round 24](ZK60_ROUND24.md) adds conditional endpoint mask/pad sampling on all
eight captured endpoint owners: 47 Python tests, 16 samples, 2,048 ideal-oracle
paths and native freeze-check pass. The public field view is still supplied
to that component; full joint/adaptive simulation remains open. Three new
Opus reviews (O9–O11) are published and ready for pickup.
[Round 25](ZK60_ROUND25.md) integrates those reviews with explicit corrections
and publishes O12–O14. It generates standalone endpoint field observations at
fixed coefficients/queries: 75 tests, eight new views, alternate-data preimages
and freeze-check pass. Full joint/adaptive simulation and external roots remain
open; the public generator does not yet cover A/H/W/CFS together.
It still lacks the complete private block,
registered private model binding and final privacy review. The historical
hash-line privacy claims below must be read with that correction. Pending
review tasks now go to [Opus 5](ZK60_OPUS_QUEUE.md).

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
proof lets anyone check, with a small program, that the hidden output came
from the specified model on the hidden input. The first PoC may use public
model weights; the full version also hides the weights.
Two properties are non-negotiable:

- **Exactness.** The model is first converted to 8-bit integer
  arithmetic (a step called *calibration*, done once per model). The
  proof is then about that integer computation bit for bit, so the
  same proof means the same thing on any hardware. A model that has
  not been calibrated cannot be proven at all; that is a feature.
- **Zero knowledge.** Inputs, outputs and intermediate activations stay
  hidden in both milestones. The full version additionally hides weights.
  The repository explores both lattice and hash-based proof engines;
  acceptance of either requires the declared privacy argument.

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
designed and proven at toy scale (§4) but is **not** in any 8B proof
on either line — including the hash line's 2026-09-03 Mistral-7B
run, which was feed-forward only (no attention, no norms, no
embeddings, and each layer's input committed from the export rather
than derived from the previous layer). Any write-up must say
"FFN-only" until round 12's lane AE lands the full layer.

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
about — and choice D now has measured rows (lanes UU and XX,
2026-09-02): a hash-based prototype proves the identical 12x512
statement in 23.0 s on the laptop's CPU alone (parity with the
lattice line's GPU-assisted 21.0 s) and in **3.40 s on the laptop's
GPU** with byte-identical proofs — 6.1x the lattice line's rate on
the same device — with 4-9x less memory and 44x larger proofs; and,
since lane ZA (2026-09-03), WITH zero knowledge for the inputs and
activations at 3.93 s on the same GPU (+60%; weights public). And on
2026-09-03 it proved **the whole Mistral-7B feed-forward stack, 32
layers x 512 tokens, on this laptop's CPU in 510 seconds** (verify
1.2 s, 14 GB) — the first full 8B proof in this project, within 4%
of its own model's prediction (§3.1, §6) — **and the same proof on
the laptop's GPU in 175 seconds, byte-identical** (5.3 GB of memory,
4.2 GB of video memory). Per proof at 8B, 225 of the CPU run's 510 s
are the weight commitments, which are per-model work when the
weights are public.

**One caution that applies to every projected number in this
repository.** The GPU result came in 1.8x below what the throughput
model predicted, and the reason is measured: 44% of the remaining
time still runs on the CPU, because the GPU kernels are written for
the small model's block shape and decline the real model's. The
model assumed all of it was GPU work — true at 125M, false at 8B.
Fixing the kernels is a known, byte-preserving change worth about
1.5x. Until it lands, treat the desktop-board and H100 columns as
upper bounds. Its
tokens-per-second model (`U_PERF3_ROUTE_B_THROUGHPUT.md`, 2026-09-02)
says: **50 tokens/s at 30B on one H100 is reachable on the hash line
only for batched proving (4-16 requests or a 512-token prefill per
proof), feed-forward only, and only if the weights may stay public
or the inputs alone are private** [MODEL, hinging on the GPU port's
measured factor]. Token-by-token decode at 50 tokens/s is not
reachable under any counted assumption on either line. Hiding the
WEIGHTS on the hash line is structurally expensive: a cached
hash-based weight commitment leaks its columns across proofs
(recoverable after ~65 proofs), so the weights must be re-committed
every proof (7-23 s of hashing per proof at 30B on an H100), unless
an uncounted design (hidden-column openings, or a lattice-hybrid
weight commitment) is built. Those designs are now priced
(`U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md`, 2026-09-02): **the one that
keeps private weights on the 50 tokens/s path is "never send the
sampled weight columns"** — commit the weights once per model under
an arithmetic hash and, on each proof, prove the verifier's column
check inside a fresh zero-knowledge inner proof; its per-proof cost
on an H100 is 0.05-3.6 s against a 4-62 s prefill proof [MODEL],
about two lane-weeks to a first measured row, and it needs its own
written security argument (the published construction it descends
from was found unsound, ePrint 2024/1164). Re-committing the weights
each proof works only with 16 or more prefills batched per proof;
the lattice-hybrid is an audit channel, not a throughput route.
The privacy scope is decided: private inputs, outputs and intermediate
activations with public weights are the first PoC (P1); weight privacy is
required in the full version (P3). The costs above are historical models,
not permission to reduce either milestone's private set.

## 3. Where we stand (the honest numbers)

### 3.1 What has been measured

| shape | machine | wall | notes | label |
|---|---|---:|---|---|
| 125M model, 12 layers x 512 tokens, the full statement | WSL laptop: Core Ultra 9 185H, 8 threads + RTX 4070 Laptop GPU (55-70 W) | **21.0 s** (commit 2.5 / prove 15.5 / verify 1.7), 6.7 GB RAM, proof 1.5 MB, 20/20 accept | the reference number, 2026-08-18; the same shape was 4,811 s on one Mac thread in July | [MEASURED, QUIET] |
| same, CPU only | same box | 81.5 s | | [MEASURED] |
| 125M, 12 x 128 | same box, GPU | 10.5 s | | [MEASURED] |
| one 8B-width layer, 16 tokens | WSL laptop | **out of memory at 15 GB** | the box cannot hold 8B; the Mac (256 GB) can | [MEASURED] |
| **one real Mistral-7B feed-forward layer, hash line (lane ZB, 2026-09-03)** | WSL laptop CPU, 8 threads | **10.5 s at 16 tokens (7.5 GB); 14.5 s at 256 tokens (10.3 GB)**; 8/8 tamper tests reject | the first proof of a real 8B-width layer in this project; the full 32-layer pass is Mac runbook item M9 (~10 min [MODEL]) | [MEASURED, NOISY-SHARED] |
| **The attention groundwork (lane AE, 2026-09-03)** | WSL laptop CPU | Mistral-7B's attention converts to exact integers cleanly at every site except the residual stream, which needs 24-bit rather than the 16 the small model needed; both the Python oracle and the Rust re-execution reproduce all 64 tensor digests of a real attention layer | the proof itself is not built yet; counted cost says a full layer is 2.9x the feed-forward-only cost at 8B, so a 32-layer full proof is about 24 minutes on this CPU against the measured 8.5 | [MEASURED chains; COUNTED cost] |
| **Privacy at 8B width (lane AD, 2026-09-03)** | WSL laptop CPU | zero knowledge for the inputs now works on the real checkpoints' arithmetic, not just the small model's: **one Mistral-7B layer costs +4.7% prover time and +3.9% proof bytes to make private**, against +17% and +24% at the small model | the cost shrinks as the model widens, because public weights dominate a wide model; privacy for the inputs is close to free at 8B | [MEASURED] |
| **The proof-size lever (lane AF, 2026-09-03)** | WSL laptop CPU | a second commitment scheme behind `--pcs compact`: **one real Mistral-7B layer's proof drops from 38.7 MB to 1.94 MB (19.9x) at 4.4x the prover time**; the 8B pass projects to ~62 MB instead of 1.23 GB | its soundness is 95-98 bits against the default's 106, which is a decision for Victor; it is not yet compatible with either the GPU path or zero knowledge | [MEASURED at one layer; COUNTED at 8B] |
| **THE SAME 8B PROOF ON THE LAPTOP GPU (lanes AC then AH, 2026-09-03/04)** | WSL laptop, 8 threads + RTX 4070 Laptop | **prove 95 s, verify 1.1 s, proof 1.23 GB byte-identical to the CPU proof, peak 3.8 GB RAM + 5.7 GB VRAM; ACCEPT** (3.02e10 proven MAC/s = 5.35x the CPU pass, 3.0 s per layer) | first 175 s by committing the weight tensors in chunks and caching them per model, then 95 s by making the kernels shape-general — the 44% that was still running on the CPU is now zero | [MEASURED, NOISY-SHARED] |
| **THE FIRST FULL 8B FEED-FORWARD PROOF: Mistral-7B, all 32 layers x 512 tokens, hash line (2026-09-03)** | WSL laptop CPU, 8 threads | **prove 510 s (8.5 min), verify 1.2 s, proof 1.23 GB, peak 14.0 GB RAM; ACCEPT** (2.886e12 MACs at 5.7e9 proven MAC/s); phases: weight commitments 225 s (per-model work), activation-side 285 s | the lattice line has never run any 8B shape (out of memory here); the hash line's own model had predicted 492 s [MODEL], measured 510 | [MEASURED, NOISY-SHARED] |
| any 8B proof end to end, lattice line | — | **never run** | Mac tasks T15-T17 (§7) | — |

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
| **Stage-A defaults, a GPU bug, and the memory diet (lane WW, Sep 2)** | the batched transport is now the default; a device-memory race that silently pushed the descent kernels to the CPU was found and fixed; the reference shape now runs in BOTH Stage-A modes on the laptop at 7.2 GB (was out of memory); Stage-A range mode proves at parity with the old path with 2.25x smaller proofs; full mode is 4x slower to prove; 8B full-mode memory ~85 GB | landed; the honest 12x512 comparison taken | `results/uperf3_ww_12x512_stage_a.md` |
| **Variant B of the two-tier opening (lane VV, Sep 2)** | per-proof weight-side opening 1.77x faster than today's at 12x512 on the laptop GPU, claims bit-identical; the bar was 5x; 8B projection 4.4-15x straddles the bar and only an 8B-scale run can settle it; needs a new per-model certificate for the value tier's range | built as a measured spike; three ruling items | `results/uperf3_vv_variant_b.md` |
| **The zero-knowledge form for the activations (lane ZA, Sep 3)** | `--zk`: private inputs and activations, public weights (mode P1); every opened value is padded or masked and tested uniform in code; proofs byte-identical CPU vs GPU under a seed; the non-ZK proof unchanged; **cost on the laptop GPU: 3.93 s vs 2.46 s (+60%), proof 87 MB vs 67 (+30%)**; on the CPU +12%; the seven tamper tests still reject | landed; the surcharge is above the memo's +2-8% estimate because two gaps in the sketch had to be closed; both privacy modes build on this | `results/hashline_zk_12x512.md` |
| **The widened-stack semantics and the first real 8B layer (lane ZB, Sep 3)** | the hash crate now proves the exact integer chain the real checkpoints were calibrated under (all 32 Mistral-7B layers' intermediate digests reproduced); the 125M statement in that form costs +3.5% on the CPU and nothing on the GPU; **one real Mistral-7B feed-forward layer proven on this laptop's CPU: 10.5 s at 16 tokens (7.5 GB), 14.5 s at 256 tokens (10.3 GB), 8 of 8 tamper tests reject** — the first proof of a real 8B-width layer ever run in this project | landed; the Mac runbook's M9 gives the Mac the full 32-layer 8B pass (~10 min [MODEL]) | `results/hashline_v3_12x512.md`, `MAC_RUNBOOK.md` M9 |
| **The hash prototype on the GPU (lane XX, Sep 2)** | the identical proof in **3.40 s on the laptop's RTX 4070** (verify 0.42 s), byte-identical to the CPU proof (same sha256, 7 runs); 8.5e9 proven MAC/s = **6.1x the lattice line's best rate on the same device**; 0.78 GB RAM + 2.4 GB VRAM; ~1.9 s of the 3.4 s is host-side work with known byte-preserving fixes, not yet applied | landed; the hash line is now measured faster than the lattice line on the same hardware | `results/hashline_gpu_12x512.md` |
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

## 7. The choices, and what was decided (2026-09-03: ROUND 11 CLOSED, ROUND 12 OPENED)

**The privacy ruling (Victor, 2026-09-03; reaffirmed 2026-09-09): P1 is the
first PoC, with hidden inputs, outputs and intermediate activations and public
weights allowed. The full version is P3 and also hides weights.** Weight
privacy remains implementation work (historical board item T18, priced in
`U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md`), not an optional full-version feature.
The following records the historical round-12 lanes. Round 12 opened four lanes on
the hash line, all toward "50 tokens/s at 30B on one H100, mode P1,
batched proving": AC (the weights committed once per model + the 8B
pass on the GPU, the measured 8B GPU number), AD (zero knowledge
composed with the 8B semantics), **AE (attention, norms and the
layer-to-layer links in the statement — the "full proof" that does
not exist yet on either line beyond toy scale; the long pole)**, AF
(the proof-size lever: 1.23 GB per 8B proof down to megabytes).
Read on for the round-11 record.

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
