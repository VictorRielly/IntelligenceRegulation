# Where the MVP stands, in plain words

**Updated 2026-09-20, after combined host/private correctness gates, by the Codex/Fable
loop (after the 01:04 laptop restart; see §3 item 4).** This page
answers three questions and is refreshed whenever the loop produces news.
Rulings are in [the decisions register](ZK60_DECISIONS.md); measurements
carry their labels ([MEASURED] a run happened, [COUNTED] arithmetic on
measured pieces, [MODEL] an estimate). Nothing here is a quiesced benchmark;
the laptop is shared with other jobs.

**Latest integrated speed work:** corrected direct-plane GPU uploads and
private host buffer/fold reuse pass 43 isolated validation steps, including
307 storage-feature tests, 189 actual-device cases and twenty frozen proof
comparisons. Main's separate rebuild and receipt checks also pass: two fresh
receipts, fourteen cross-version verifications and 24 GPU-feature private-IO
tests under all buffer/fold settings. Floors v11 pins the new inventory, with
89 tooling tests passing. [Evidence and limits](ZK60_HOST_PRIVATE_INTEGRATION_20260920.md).
These checks establish correctness; they do not measure private-model speed.

The preceding exact int8/int32 row folds pass all twelve
CPU/GPU proof-byte gates, fresh native receipt verification in both modes,
and repaired private-IO P1/P3 checks. Dense synthetic folds improve
2.32–2.42x; sparse cases are mixed. Full-model proving time remains
unmeasured. [Evidence and limits](ZK60_ROWFOLD_INTEGRATION_20260919.md).

**Latest on the fast line's private block (added 2026-09-20 07:10 by the
security owner's session):** one **complete transformer block with hidden
input, hidden output and hidden activations now proves and verifies at a real
model's shape** — the 125M class: 512 tokens, width 768, hidden 2048, 12 query
heads over 4 key-value heads — on the fast native line, on this laptop's CPU.
**Prove 26.89 s, verify from bytes 1.04 s, receipt 40,782,792 bytes, peak
memory 10.42 GiB** [MEASURED, one run, shared box, 2026-09-20 07:03; the
paper model had said 25–36 s and about 11 GiB]. What that is and is not:
**synthetic weights, one block of twelve, no GPU, and NOT a privacy claim at
this shape** — the privacy checks are owed again at every new shape and need
capture bundles that do not exist yet. Before it ran, the design was attacked
on paper (a padding hole was found and closed before anyone built it), grown
test-first through a small padded shape, and the code was attacked by an
independent reviewer who could not get a false statement accepted; the toy
block's bytes are unchanged, confirmed by verifying receipts made before the
work began. Lane `zk60-private-block-125m` (pushed, not yet integrated);
ledger `ZK60_BLOCK125M_LANE_PROGRESS.md` on that branch. **For the toy block
only, the privacy argument now has a checked core at every step**;
the three rulings from Victor were accepted at 13:45, followed by D22 below
([one page](ZK60_RULINGS_FOR_VICTOR_PRIVACY.md);
[superseded draft](ZK60_PRIVACY_STATEMENT_TOY_PROFILE_DRAFT.md)).

**First privacy acceptance on the fast line (2026-09-20 13:46, register
D22):** the **toy private block** — one block, 32 tokens, width 16, public
synthetic weights — is accepted as private by the security owner, in the model
Victor accepted the same day (D19 the hash as an ideal random function, D20
timing/memory/power out of scope with refusals kept in, D21 rejected receipts
never sent and captures counted as publishing): a verifier's view is within
about 2^-77.7 per proof of one that does not depend on the hidden data. **For
that one small artifact and nothing else** — not the 125M block below, not any
multi-block run, not real weights, not sealing in advance. It is an argument
whose every step survived one independent attack, not a proof the security
owner re-derived; [the statement](ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md) lists
its residuals, the seven conditions under which it lapses and what reopens it.

**The separating hash tag is in, and the twelve-block run was re-measured
under it (added 2026-09-20 16:40):** decision D19 obliged every new shape to
hash its transcript, its column digests, its Merkle leaves and its Merkle
nodes under separate keys. That is built (register D19a; BLAKE3's keyed mode,
four public keys per shape, the verifier deriving them from the profile it
trusts; the toy block is never tagged, so the accepted bytes above do not
move), reviewed by the security owner, and authorised by the integrator as an
additive change to its files. **Under the tag, all twelve blocks at the 125M
shape prove and verify as one run: prove 393.59 s, verify by streaming
14.09 s, receipt 484,100,736 bytes (equal to the counted figure), peak memory
10.15 GiB; one block alone: prove 27.87 s, verify 1.21 s, 40,782,792 bytes**
[MEASURED, one run each, shared laptop with an agent active, CPU only, finished
16:39]. That is about 5% slower than the morning's untagged runs (370.61 s;
26.54 s) — **not attributable to the tag**: the two hashing phases moved one
up and one down, and a phase with no hashing in it moved more than either.
**A caveat on every 125M figure on this page, found 2026-09-20 17:30:** the
synthetic public weights used by all shaped tests are *diagonal* (64 on the
diagonal, zero elsewhere). Where the hidden layer is wider than the model
(2048 against 768), the upper part of the hidden layer therefore carries zeros
in every proof run so far: the wide geometry has been exercised in its sizes,
padding and checks, **not in its numbers**. No defect was found (the layout
was read line by line and one public table re-derived by arithmetic), and
proving time barely depends on the values (one phase skips zero weights; about
a second per twelve-block run [MODEL]). A dense-weights test with a
non-trivial hidden input is being added now, at the development size first.
The run now leaves its **public statement** beside its segments (written only
after the whole run verified), so a fresh process can check it. **Still no
privacy claim for anything but the toy block**, and the integrator has not yet
integrated or reproduced these runs.

**ALL TWELVE BLOCKS, ONE PROOF (added 2026-09-20 11:25):** a **private run of
all twelve transformer blocks at the 125M shape — hidden input, hidden output,
every activation and every block-to-block boundary hidden — proves and
verifies under one transcript: prove 370.6 s (6.2 minutes, about 30.9 s per
block, flat), verify 13.7 s by streaming one 40 MB segment at a time, receipt
484,100,736 bytes (equal to the counted figure to the byte), peak memory
10.15 GiB, on this laptop's CPU** [MEASURED, one run, shared box, finished
11:22]. What it is not: **synthetic weights, not a trained checkpoint; the
blocks only (no embedding, no output head — decision D13 says the blocks are
enough for the first MVP); no GPU; and no privacy claim for a run exists yet**
— the privacy checks for a multi-block run are designed and not built. Its
whole-run soundness is about 2^-97.5 by the project's accounting and its
receipt is 484 MB against a 256 KB budget; both are on Victor's page as
deviations for him to rule on.

**And blocks now chain (added 2026-09-20 10:48):** a private **run of two
blocks under one transcript** — block 1's hidden output is block 2's hidden
input, never published — proves and verifies at the same 125M shape: **prove
62.9 s, verify 2.0 s, receipt 81.1 MB in two segments** [MEASURED, one run,
shared box, CPU]. A verifier rejects a second block that was run on anything
other than the first block's output. This matters because separately finished
private proofs cannot be joined afterwards; a full model has to be one run.
Twelve blocks are counted at about 6.3 minutes of proving, 12.5 s of verifying
and 484 MB [COUNTED], with a whole-run soundness of about 2^-97.5 by the
project's accounting — and **no privacy claim exists for any run yet**; the
design, its independent check and the rulings are
[here](ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md) (register entry D12a).
Where a private block's 26.5 s goes is measured too: one softmax check 25%,
lookup inversions 15%, the two commitments 25%, the feed-forward part 5%
([plan §5.2b](ZK60_MVP_COMPLETION_PLAN.md)).

## 1. Do we have a workable proof?

**A complete small-block experiment works. The model MVP remains open.** Today at 19:18 the
first complete transformer block (T32 tokens, width 16, FFN 16, two heads,
the real integer kernel: both RMS norms, QKV, RoPE, causal integer softmax
attention, PV, output projection, both residuals, SiLU FFN) was proven by
re-execution inside the RISC Zero zkVM and wrapped into a **785-byte Groth16
receipt** that verifies in a fresh process in 8 ms. Seven corruption
controls (wrong context, model, input, output; truncated, trailing,
tampered bytes), plus the inner receipt kind, are rejected. Inputs, outputs
and activations are hidden under the reviewed Groth16 premises;
the public artifact is the receipt plus a 144-byte policy of digests.

| Stage | Result | Label |
|---|---|---|
| inner STARK proof (succinct receipt, 223,514 bytes) | 3,743 s on the shared laptop CPU, two threads | [MEASURED, NOISY-SHARED] |
| Groth16 wrap with the extracted native prover | 197 s | [MEASURED, NOISY-SHARED] |
| independent verification | 0.008 s | [MEASURED] |

**And, at 21:34, the first proof of actual token generation:** the
two-block token model (public embedding, two complete blocks with their
hidden seam, final norm and head, greedy next token; synthetic T32 fixture
with a 32-word vocabulary, not a trained model) proven by re-execution and
wrapped to a 785-byte Groth16 receipt; independently verified, eleven
rejection controls pass, and the block-profile verifier refuses it as a
different profile. Prove 7,488 s (2 h 5 min) on the shared CPU, wrap 197 s
[MEASURED, NOISY-SHARED]. Public artifacts retained under
`results/zk60_loop_20260918/token-integration/token_public/`.

What it rests on: RISC Zero's proof system at about 97 bits conjectured
soundness (D3), the Groth16 trusted setup (D4), Groth16 receipts only (D5),
and the salted-SHA-256 endpoint profile accepted under D7 at 11:50 on
September 19. The D7 qualifiers remain explicit: salt secrecy protects the
toy answer (the model library still accepts zero/repeated salts), the image
is locally built and not independently reproduced across directories, and
timing is declared leakage; the scan and cycle check cover only the block
program. Both receipts use synthetic tiny fixtures and make no model-speed
claim. D13 makes hidden model blocks the first MVP; token generation follows.

**On the custom prover line (hashline), the first complete private block now
proves and verifies (2026-09-19, 05:14), and at 06:25 the security owner
accepted it as an experimental component — still not a privacy acceptance.**
The same kind of block as above (T32 tokens, width 16, two heads,
feed-forward width 16: attention, both norms, both residuals, the SiLU
feed-forward) in **one native proof with no seam**, inputs, outputs and
activations hidden, weights public, on a public synthetic fixture. On the
security owner's own run: **prove 0.095 s, verify 0.043 s in a fresh process
from bytes only, receipt 2,816,472 bytes** — exactly the size the design
derived before any code existed [MEASURED, NOISY-SHARED, diagnostic only]; 38
unit, parity and tamper tests and 4 integration tests pass; the witness
matches the integer reference kernel element for element on 1,200 cases,
refusing exactly where the kernel refuses; nine tampers, including the one
that would let a prover choose the block's output, are rejected by the
verifier. For scale: the zkVM line needed 3,743 s for the same block. Since
then (05:49) **the project's leak-checking tools have been run on the real
source** (46 of 46 counts equal the design, nothing disclosed in any opening
group or at either endpoint, all 22 negative controls fire, zero differences
from the paper run) and **an independent adversarial code review found no
blocking problem** (every hidden plane is pinned, every relation equals the
reference kernel's, it could not construct a false proof the verifier
accepts); its two small defects and its missing tamper tests were closed by
06:19, every new tamper caught exactly where it was predicted, including the
one case where only a single lookup stands between a prover and a free hidden
value; 46 unit and 4 integration tests pass on the security owner's own run,
and a receipt made before those fixes still verifies after them. **What it
is not:** not a privacy acceptance (those tools check a
linear-algebra model that leaves out several channels; the caller-fixed-root
obligation D8/D11 is open; the joint-view gate on captured receipts is
unmet), not a trained model, and **not a speed result for 8B**: the form
built here deliberately gives up the GPU feed-forward prover, and a tenth of
a second at width 16 says nothing about width 4096. Branch
`zk60-private-block`; record
`results/zk60_private_block_evidence/README.md` there.

**Codex integration, 2026-09-19:** both native profiles are now in the main
worktree. The integrated block produces a fresh 2,816,472-byte receipt in
0.062–0.064 s and verifies it independently in 0.020–0.021 s on this shared
CPU with two threads; the original lane receipt verifies too [MEASURED,
NOISY-SHARED, tiny fixture only]. Fifty-seven combined Rust tests, 29
block-inventory tests, the full Python regression (1,098 tests, 61 skipped)
and native freeze pass. Attention's repeated byte-lookup inversions are
removed and its fixture scale labels corrected. Whole-proof privacy and
model-scale speed remain open. [Integration and evidence](ZK60_ATTENTION_INTEGRATION_20260919.md).

**Verifier captures now retained:** source-pinned recordings from two fresh
attention receipts and two complete-block receipts reproduce exactly in fresh
verifier processes. They include all 18/23 slots, M and PCS openings, pads,
sampled columns, salts and paths. Forty-nine native unit tests and 13 Python
capture controls pass; both pre-instrumentation receipts still verify.
[Capture format and review boundary](ZK60_NATIVE_CAPTURE.md),
[validation manifest](../../results/zk60_native_captures_20260919/validation.json).
This closes the capture-writer prerequisite. The complete joint-view analysis
and D8/D11 still need acceptance; no new proving-speed claim follows.

**GPU optimization validated:** Claude's compact intermediate for non-hiding
openings and the parallel host column split pass the integration checks:
261 CPU Rust tests, four configurations of 34 required-device commitment
tests, 12 device cache tests, all twelve frozen CPU/GPU/forced-chunked proof
digests, and native freeze. The full Python run covered 1,140 tests (61
skipped); its single lock-related error is resolved by a test-isolation fix
and a passing 18-test targeted rerun.
The local four-kernel gain is 1.162× [MEASURED]; its full-pass saving is only
0.8–1.8 seconds [COUNTED]. No new 8B proof clock is claimed. The next host
work targets redundant integer conversion/packing and repeated reductions.
[Review and retained evidence](ZK60_FSP_L9_INTEGRATION_20260919.md).

What else exists on that line: a private feed-forward component at the same tiny shape
with a bounded privacy diagnostic (whole-proof privacy not accepted, D8
open); public-IO proofs of real 8B feed-forward stacks (below); the private
attention schedule designed and rank-checked, and its native implementation
built and reviewed at the tiny geometry as an experimental component (§3
item 1).

## 2. How slow are we against the target?

The written target is **5 to 15 seconds per proof of an 8B model's
feed-forward blocks over 512 tokens, on one consumer GPU** (p95 over 20
warm runs, idle machine). The only line that can approach it is the custom
prover.

| What was proven | Where | Time | Distance from 5 s | Label |
|---|---|---|---|---|
| Mistral-7B, all 32 feed-forward layers × 512 tokens, **public IO**, lane AL after the host fix | laptop RTX 4070 (55–70 W) | prove **58.40 s**, verify 1.08 s, proof 1.23 GB | **11.7× slower** than 5 s, 3.9× slower than 15 s, for the proving phase | [MEASURED, NOISY-SHARED, 2026-09-04] |
| same, CPU only | laptop, 8 threads | 510 s | 100× | [MEASURED] |
| the same stack **with attention and accepted P1 privacy** | not yet built at 8B | no measurement | unknown | earlier ~290 s estimate withdrawn: the +4.7% CPU surcharge does not transfer to the GPU, and the legacy privacy profile has disclosure defects |
| one tiny complete block in the zkVM (above) | laptop CPU | 3,743 s for roughly 10^5 multiply-accumulates; the 8B FFN pass is 2.9 × 10^12 | not a performance path at all: the zkVM line is the privacy demonstrator, never the product prover (D2) | [MEASURED; COUNTED] |

The newer lane-AL result supersedes the earlier 95-second lane-AH headline.
Its retained log also records **134.50 s witness load+chain** and **196.79 s
total wall**; 58.40 s is the proving phase, not complete request readiness.
[Original measurement](../../results/hashline_convert_r3.log).

**Activation-side arithmetic (weight-commit phase subtracted).** The table
divides 512 tokens by the measured prove time minus its weight-commit phase
(Mistral-7B, 32 FFN layers, `results/hashline_zk_8b_gpu.md` §2). This is an
optimistic accounting boundary, not a measured warm-cache rate: `--wcache`
still pays validation, upload and encoding work. Its warm-path performance
must be measured on the current implementation.

| run | prove | of which commit W | activation side | **tokens/s, W phase subtracted** | with W |
|---|---:|---:|---:|---:|---:|
| public IO, laptop GPU (lane AL, 2026-09-04, host fix, cold W cache) | 58.40 s | 19.823 s | 38.577 s | **13.3** | 8.8 |
| public IO, laptop GPU (lane AH, 2026-09-04) | 95.5 s | 41.9 s | 53.5 s | **9.6** | 5.4 |
| legacy `--zk`, laptop GPU (lane AI, same day; card 8.2 GB, run paged at 8.6 GB; privacy claim subsequently invalidated) | 265.3 s | 54.2 s | 211.2 s | **2.4** | 1.9 |
| public IO, laptop CPU (2026-09-03) | 510 s | 225 s | 285 s | **1.8** | 1.0 |

Labels: [MEASURED, NOISY-SHARED] per row; the division is [COUNTED]. These
are prefill rates (512 tokens per proof), FFN-only. The legacy `--zk` row was
starved of video memory (55% of its time is one paging-bound phase). It is
not a measurement of the repaired private profile or of a larger card.
The legacy profile's known disclosure defects remain decisive regardless
of those timings. One-token-at-a-time decode is far worse per
token: a single layer at 16 tokens cost 72% of the same layer at 256 on
the CPU, so per-token cost at small batches is 10–20× the prefill figure
[COUNTED from one measurement]; no decode run exists at 8B.

A bigger GPU (a 5090 or an H100) has not been measured. The project's own
throughput model says the built design does not reach the goal on any GPU
without the recorded design changes (preprocessed weights, the two-tier
opening; `START_HERE.md` §2 and §5), and that those changes were counted,
not built. Honest summary: **on today's laptop the public-IO 8B proof is
one to two orders of magnitude off the target, and the private version of
it does not exist yet.**

## 3. What blocks a private, model-scale MVP at speed, and what is being done

1. **Private attention on the custom line: implemented and reviewed at the
   tiny geometry (2026-09-18, late evening).** A delegated Fable lane built
   the native masked prover and verifier to the construction; the security
   owner's lane compiled it with zero fixes, ran its 16 tests, proved and
   fresh-process-verified the example (0.09 s, 2.2 MB receipt), regenerated
   the rank and CFS checks on the layout it actually declares (nothing
   disclosed; H residual = the public identity; all 18 slots and 5 host
   groups pass) and re-derived the arithmetic bounds (all hold). Accepted as
   an experimental component (`ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md`
   on branch `zk60-attention-compile`). Using one 8-bit range table instead
   of the 65,536-entry ones cut the commitments to 306 and 290 rows. Still
   missing for this attention-only profile: the second norm, the FFN and
   residual 2; the complete-block profile above now includes them.
   The 2026-09-19 gap inventory
   (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md` on `zk60-attention-compile`)
   sorted fifteen gaps into engineering and construction work under D12.
   The capture writer, fixture scale-tag fix and tiny-block kernel parity
   are now implemented and tested; model-width construction remains open.
2. **Whole-proof privacy acceptance on the custom line.** The joint-view
   tools exist and real native captures are retained. Their joint-view
   adapters and the caller-fixed-root obligation are still open (D8/D11).
3. **Speed.** The gap above is a design gap, not a tuning gap.
4. **Current lanes:** Fable's GPU kernels and host staging port, then a
   separately labelled repaired-mask cost probe; Codex's capture review
   handoff and remaining zkVM hardening/ceremony integration. No model-width
   GPU measurement window is reserved. The two-block token-model proof landed
   (§1). **Earlier restart/build history:** the
   laptop restarted at 01:04 on 2026-09-19**: git and the retained receipts
   are intact and everything was already pushed, but the `/tmp` scratch area
   is gone, which killed the queued ceremony checker before it ran (Codex
   relaunches it) and erased the uncommitted Opus phase-diagnostics work
   (restarts from zero). **Both Groth16 receipts were re-verified in fresh
   processes after the restart** (block and token; each profile's verifier
   refuses the other's receipt) [MEASURED]. Three read-only reviews by the
   security owner's Opus agents landed by 01:30: the token model's source
   review (no code defect; the retained build-source record is stale for
   the wrapper; hardening items for Codex), the response to Codex's review
   of the hardening lane (all six of its findings correct, four already
   fixed soundly, one new low-severity gap), and the inventory of what a
   complete private block on the custom line still needs. That inventory's
   central finding is now **ruling D12**: the two existing components may
   not be joined by sharing one hidden commitment between two proofs,
   because two openings at that geometry reveal all 512 hidden words; a
   block is one proof under one transcript, and the second norm must prove
   its output's range because the feed-forward prover does not. **At 03:01
   the design of the complete private block was accepted as the design to
   build** (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` on
   `zk60-attention-compile`): the attention construction is grown into the
   whole block, so there is no seam to prove; drafted and independently
   checked by delegated agents, with the project's rank and slot tools run on
   a paper description of the whole block (nothing disclosed; every negative
   control fires) [COUNTED on a description, not measured on code]; 22
   corrections made binding, including two that would have been soundness
   holes (a block whose output the prover could choose, and an activation
   table whose value range nothing enforced). This is a design, not a privacy
   acceptance and not a speed result. Expected size at the tiny shape: a
   2.8 MB receipt. Building started on `zk60-private-block` at 04:07;
   the initial witness-only checkpoint was subsequently superseded by the
   complete proof and its integration described in §1. Earlier items:
   the security owner's source review of `zkvm-block/` with eight hardening
   items (`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` on branch
   `zk60-mvp-fable`), now implemented and verified on branch
   `zk60-zkvm-hardening` for Codex to integrate (secret-scan stage,
   environment refusal and scrub, cycle reporting, constant-cycle gate with a
   real executor run, tool-check command, work-directory cleanup,
   claim-shape regressions). Codex reviewed that delivery (no acceptance
   defect in the Rust; one runner incompatibility with the token profile and
   several wording and test-scope corrections, which Codex is applying). The
   ceremony checker never ran (see the restart above); no ceremony-check
   success is claimed. **Rulings made by Victor on 2026-09-19 (11:50):** D7
   accepted — the zkVM line's two receipts may now be called private under
   D3, D4, D5 and D7, with three written qualifiers (salt secrecy carries the
   32-value toy answer; the program's identity depends on its build
   directory; timing is declared leakage); D9 accepted as stated (a privacy
   residual of about 2^-72); D10 declined (the compact proof format cannot
   run privately); new D13, the hidden blocks are enough for the first MVP
   and generating a word is the next milestone; new D14, a costed memo for
   the one design lever that could take a 5090 below 10 s, paper only; and
   the RTX 5090 install is a go (date, machine and RAM still to be named).
   **Speed, honestly, as of 13:42 (`ZK60_FIVE_SECOND_PLAN.md`, three dated
   corrections at the top of its §5):** 5 s is outside every assumption
   recorded in this repository, and the costed memo commissioned under D14
   confirms the one design lever left cannot reach it (best case on a 5090
   about 7–9 s, for 15–25 lane-weeks and a 60% larger proof). The plan's three
   software steps were built today, all byte-identical and green: together
   they are worth **about 4–5 s of the 58.40 s [COUNTED]**, not the 24 s first
   projected — every counted step shrank three- to seven-fold when measured.
   On this laptop the public 8B pass is a roughly 55 s pass. Whether the 5090
   reaches 15 s is **open** until its first measurement; 16–19 s of today's
   pass is host work the card does not touch.
   **The most valuable missing number now exists, at the small shape:** the
   *repaired* private mask scheme ran for the first time above the tiny shape
   (45 runs, zero refusals, 12 layers × 512 tokens at the 125M shape, three
   arms on one binary, endpoints public in all three — a cost probe, not a
   privacy result): **repaired ÷ legacy = 1.06 on the GPU binary and 1.00 on
   the CPU binary; repaired ÷ public = 2.05 on the GPU** [MEASURED]; proof
   bytes +0.75% over legacy; by row count +1.8% at Mistral width and about
   +1.6% on a Mistral layer [COUNTED, not run]. So the repaired masks cost
   what the legacy ones did, within a few per cent; what is still unmeasured
   is the other half of P1, the hidden endpoints at model width.
   **Privacy path, same day:** on Codex's retained captures of two block and
   two attention receipts, a gate that replays the transcript at the
   receipts' real challenges finds nothing determined about the hidden data
   beyond public identities, with the 256 sampled columns included, and every
   sabotage control caught — evidence on a linear model of four receipts,
   **not** a privacy acceptance (D8/D11 open); and the private block's norm
   was shown free of the soundness gap the older prover has, with the
   precondition for widening it recorded as D16.
5. **A reproducibility fact to settle before any approval record:** the
   guest image ID depends on the build directory (the ELF embeds one
   absolute source path and the non-Docker build applies no path remap), so
   the approved ID `8d74aab3…98d9` is reproducible only from the main
   checkout's path or from a reproducible Docker build.

## 4. Where the evidence is

Public artifacts of today's Groth16 receipt are retained under
`results/zk60_loop_20260918/block-integration/groth16_public/` (policy,
receipt, public model, stage records, hashes); the `/tmp` originals do not
survive a reboot and a new randomized receipt would have different bytes. The loop's own
record is `ZK60_MVP_LOOP_20260918.md`.
