# Where the MVP stands, in plain words

**Updated 2026-09-18, evening, by the interactive Fable session.** This page
answers three questions and is refreshed whenever the loop produces news.
Rulings are in [the decisions register](ZK60_DECISIONS.md); measurements
carry their labels ([MEASURED] a run happened, [COUNTED] arithmetic on
measured pieces, [MODEL] an estimate). Nothing here is a quiesced benchmark;
the laptop is shared with other jobs.

## 1. Do we have a workable proof?

**Yes, for one small complete block, with privacy.** Today at 19:18 the
first complete transformer block (T32 tokens, width 16, FFN 16, two heads,
the real integer kernel: both RMS norms, QKV, RoPE, causal integer softmax
attention, PV, output projection, both residuals, SiLU FFN) was proven by
re-execution inside the RISC Zero zkVM and wrapped into a **785-byte Groth16
receipt** that verifies in a fresh process in 8 ms. Seven corruption
controls (wrong context, model, input, output; truncated, trailing,
tampered bytes) are rejected. Inputs, outputs and activations are hidden;
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
attention schedule designed and rank-checked but not implemented.

## 2. How slow are we against the target?

The written target is **5 to 15 seconds per proof of an 8B model's
feed-forward blocks over 512 tokens, on one consumer GPU** (p95 over 20
warm runs, idle machine). The only line that can approach it is the custom
prover.

| What was proven | Where | Time | Distance from 5 s | Label |
|---|---|---|---|---|
| Mistral-7B, all 32 feed-forward layers × 512 tokens, **public IO** | laptop RTX 4070 (55–70 W) | prove 95 s, verify 1.1 s, proof 1.23 GB | **19× slower** than 5 s, 6× slower than 15 s | [MEASURED, NOISY-SHARED, 2026-09-04] |
| same, CPU only | laptop, 8 threads | 510 s | 100× | [MEASURED] |
| the same stack **with attention and privacy** (not yet built at 8B) | laptop GPU | about 290 s: attention counted at 2.9× the FFN cost, input privacy measured at +4.7% at 8B width | about 60× | [COUNTED from measured pieces] |
| one tiny complete block in the zkVM (above) | laptop CPU | 3,743 s for roughly 10^5 multiply-accumulates; the 8B FFN pass is 2.9 × 10^12 | not a performance path at all: the zkVM line is the privacy demonstrator, never the product prover (D2) | [MEASURED; COUNTED] |

**Amortized rate (weight commitment excluded).** The weight commitment is
per-model work (cached by `--wcache`), so in the limit of many proofs the
rate is 512 tokens over the activation-side prove time of one 512-token
proof (Mistral-7B, 32 FFN layers, `results/hashline_zk_8b_gpu.md` §2):

| run | prove | of which commit W | activation side | **tokens/s, amortized** | with W |
|---|---:|---:|---:|---:|---:|
| public IO, laptop GPU (lane AH, 2026-09-04) | 95.5 s | 41.9 s | 53.5 s | **9.6** | 5.4 |
| private P1, laptop GPU (lane AI, same day; card 8.2 GB, run paged at 8.6 GB) | 265.3 s | 54.2 s | 211.2 s | **2.4** | 1.9 |
| public IO, laptop CPU (2026-09-03) | 510 s | 225 s | 285 s | **1.8** | 1.0 |

Labels: [MEASURED, NOISY-SHARED] per row; the division is [COUNTED]. These
are prefill rates (512 tokens per proof), FFN-only (attention counted at
2.9× the FFN cost would divide them by about 3), and the private row was
starved of video memory (55% of its time is one paging-bound phase), so it
understates a card with room. One-token-at-a-time decode is far worse per
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

1. **Private attention on the custom line.** Designed
   (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md`, schedule JSON, rank and CFS
   checks green) but unimplemented; Codex owns the protocol Rust. Cost at
   the tiny shape is about 77 MB of extra committed rows, dominated by two
   65,536-entry range tables.
2. **Whole-proof privacy acceptance on the custom line.** The joint-view
   tools exist; the caller-fixed-root obligation is open (D8/D11).
3. **Speed.** The gap above is a design gap, not a tuning gap.
4. **In flight now (Codex's loop):** a two-block token-model guest for the
   zkVM line (`zkvm-model/`, headless Fable lane delivered, Codex building);
   the security owner's source review of `zkvm-block/` with eight hardening
   items (`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` on branch
   `zk60-mvp-fable`); pending rulings D7, D9, D10.

## 4. Where the evidence is

Public artifacts of today's Groth16 receipt are retained under
`results/zk60_loop_20260918/block-integration/groth16_public/` (policy,
receipt, public model, stage records, hashes); the `/tmp` originals do not
survive a reboot and the receipt cannot be regenerated. The loop's own
record is `ZK60_MVP_LOOP_20260918.md`.
