# Where the MVP stands, in plain words

**Updated 2026-09-18, evening, by the Codex/Fable integration loop.** This page
answers three questions and is refreshed whenever the loop produces news.
Rulings are in [the decisions register](ZK60_DECISIONS.md); measurements
carry their labels ([MEASURED] a run happened, [COUNTED] arithmetic on
measured pieces, [MODEL] an estimate). Nothing here is a quiesced benchmark;
the laptop is shared with other jobs.

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

What it rests on: RISC Zero's proof system at about 97 bits conjectured
soundness (D3), the Groth16 trusted setup (D4), Groth16 receipts only (D5),
and a new salted-SHA-256 endpoint profile that still needs Victor's
acceptance as the P1 statement (D7). It is one block, not a model; it
generates no tokens; it makes no speed claim.

**On the custom prover line (hashline), no complete private block exists.**
What exists there: a private feed-forward component at the same tiny shape
with a bounded privacy diagnostic (whole-proof privacy not accepted, D8
open); public-IO proofs of real 8B feed-forward stacks (below); the private
attention schedule designed and rank-checked, with its native implementation
now assigned to Claude Fable 5.1 in an isolated worktree.

## 2. How slow are we against the target?

The written target is **5 to 15 seconds per proof of an 8B model's
feed-forward blocks over 512 tokens, on one consumer GPU** (p95 over 20
warm runs, idle machine). The only line that can approach it is the custom
prover.

| What was proven | Where | Time | Distance from 5 s | Label |
|---|---|---|---|---|
| Mistral-7B, all 32 feed-forward layers × 512 tokens, **public IO** | laptop RTX 4070 (55–70 W) | prove 95 s, verify 1.1 s, proof 1.23 GB | **19× slower** than 5 s, 6× slower than 15 s | [MEASURED, NOISY-SHARED, 2026-09-04] |
| same, CPU only | laptop, 8 threads | 510 s | 100× | [MEASURED] |
| the same stack **with attention and accepted P1 privacy** | not yet built at 8B | no measurement | unknown | earlier ~290 s estimate withdrawn: the +4.7% CPU surcharge does not transfer to the GPU, and the legacy privacy profile has disclosure defects |
| one tiny complete block in the zkVM (above) | laptop CPU | 3,743 s for roughly 10^5 multiply-accumulates; the 8B FFN pass is 2.9 × 10^12 | not a performance path at all: the zkVM line is the privacy demonstrator, never the product prover (D2) | [MEASURED; COUNTED] |

**Activation-side arithmetic (weight-commit phase subtracted).** The table
divides 512 tokens by the measured prove time minus its weight-commit phase
(Mistral-7B, 32 FFN layers, `results/hashline_zk_8b_gpu.md` §2). This is an
optimistic accounting boundary, not a measured warm-cache rate: `--wcache`
still pays validation, upload and encoding work. Its warm-path performance
must be measured on the current implementation.

| run | prove | of which commit W | activation side | **tokens/s, W phase subtracted** | with W |
|---|---:|---:|---:|---:|---:|
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
   missing for a block: the second norm, the two FFN seams and residual 2;
   Codex integrates.
2. **Whole-proof privacy acceptance on the custom line.** The joint-view
   tools exist; the caller-fixed-root obligation is open (D8/D11).
3. **Speed.** The gap above is a design gap, not a tuning gap.
4. **In flight now (Codex's loop):** a two-block token-model proof for the
   zkVM line (`zkvm-model/`: 24 tests and actual execution pass; proving now
   runs under the shared lock);
   the security owner's source review of `zkvm-block/` with eight hardening
   items (`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` on branch
   `zk60-mvp-fable`), now implemented and verified on branch
   `zk60-zkvm-hardening` for Codex to integrate (secret-scan stage,
   environment refusal and scrub, cycle reporting, constant-cycle gate with a
   real executor run, tool-check command, work-directory cleanup,
   claim-shape regressions). Codex is reviewing that delivery. The reviewed
   ceremony checker is queued behind the token proof and artifact preparation;
   no ceremony-check success is claimed yet. Opus 5 is adding private phase
   diagnostics for the repaired FFN. Pending rulings remain D7, D9, D10.
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
