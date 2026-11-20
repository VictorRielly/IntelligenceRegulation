# Research handoff: verification of relayed figures against primary sources (2026-11-16, claude-cycle 5)

From Claude, the standing researcher (D50).

**Scope.** Verification only, no new research. 1 search and 15 page reads (project repository pages, eprint.iacr.org,
arxiv.org and a mirror of the Thaler paper). No build, proof, GPU run, experiment or Git write. Searches and fetches
carried no project name, owner name or path. Fetched pages were treated as data. The fetch tool summarizes pages with a
small model and limits quotes to about 125 characters, so quotes below are verbatim fragments or table cells as the tool
returned them. The earlier handoffs (cycles 1-3) were not edited.

Status words: CONFIRMED (the source says it), CORRECTED (the relayed figure or description is wrong or loose; the right
value is given), COULD NOT VERIFY (what was tried).

## Summary table

| # | Item | Relayed figure | Status | Evidence |
|---|---|---|---|---|
| 1a | FlashProve tok/s at batch 1 / 8 / 24 / 64 | 17.4 / 76.3 / 111.2 / 123.3, one H100, 1,024-token windows | CONFIRMED | `guide/performance.md` table: "1 \| 17.41 ± 0.15", "8 \| 76.34 ± 0.37", "24 \| 111.23 ± 0.92", "64 \| 123.31 ± 0.42". Seconds per request 58.796 / 13.413 / 9.206 / "-" (none at 64). README: "FlashProve runs Llama 4 Maverick at full size, with a 1,024-token context window, on a single NVIDIA H100." and "The prover reaches about 110 tokens/second of prefill at 24 requests per batch." URLs: https://github.com/anthropics/FlashProve/blob/main/guide/performance.md and https://github.com/anthropics/FlashProve. See note A. |
| 1b | Receipt size per request | 18.8 MB per 1,024-token request | CONFIRMED (size) with caveat on "1,024-token" | performance.md: "A proof is 18.78 MB on average." The README states a 1,024-token context window, not that every proof covers 1,024 tokens (its examples use 64 and 1,001 tokens). Rate x time per request is 17.41 x 58.796 = 1,023.7 and 111.23 x 9.206 = 1,024, consistent with 1,024 tokens per request. Say "18.78 MB average per proof, at a 1,024-token window". |
| 1c | Latency at batch 24 | 221-226 s | CONFIRMED | performance.md column "From a batch's start to its proofs, after the first batch": 24 -> "220.7 to 225.9 s"; 64 -> "533.3 to 537.9 s". The page says these run "to the release of its responses by `cp_prove`, which was called directly and runs no verifier." |
| 1d | Provider-side check time | about 94 s | CONFIRMED | performance.md: "The check of a batch of 24 proofs took 94.0 seconds, and of one proof alone 22.6 seconds". Single-thread C++ verifier "about 21 seconds". One reported run, not a mean. |
| 1e | Overhead vs plain inference | 71-93x vs vLLM prefill | CONFIRMED with caveats | performance.md: "per GPU, proving at 24 per batch is 93.0 times slower (92.2 to 94.1 over all pairs of runs) than stock vLLM's prefill at the highest load tried, and 71.4 times slower (65.2 to 76.4) than its prefill of 24 requests at once." See note B. |
| 2a | ePrint 2026/1250 | "TensorZKP", tensor-core sumcheck and encoding | CONFIRMED | Title "TensorZKP: Repurposing GPU Tensor Cores for High-Performance Zero-Knowledge Proofs"; authors Tao Lu, Jipeng Zhang, Yanpei Guo, Wenjie Qu, Jiaheng Zhang (NUS), Xuanming Liu, Zonghui Wang, Wenzhi Chen (Zhejiang). Abstract (summarized by the tool): adapts finite-field arithmetic to Tensor Cores, recasts sum-check and Spielman code as matrix multiplications; implemented with HyperPlonk and Brakedown. Headline: "proof generation time of only $215.28$ milliseconds" for 2^25 multiplication gates, 955x over CPU baseline, 36.2x over SIMT GPU implementations. https://eprint.iacr.org/2026/1250 |
| 2b | ePrint 2026/2681 | improved Ligero analysis | CONFIRMED | "Improving Code Rate and Query Complexity for the Ligero-IOP System", Cascudo, Hazay, Venkitasubramaniam; received 2026-10-29, revised 2026-11-02. "we analyze the original Ligero IOP in the list-decoding regime and show that mutual correlated agreement suffices ... to obtain improved soundness guarantees and lower query complexity, without modifying the protocol." Also "enabling Reed--Solomon code rates above 1/2 ... while achieving perfect honest-verifier zero knowledge." https://eprint.iacr.org/2026/2681 |
| 2c | ePrint 2026/2481 | improved Ligero analysis (as relayed) | CORRECTED (description) | The identifier resolves, but it is not an improved analysis of Ligero. Title "Polygero: Proximity Testing From Polynomial Challenges", Frigo and shelat (Google); received 2026-10-14. Abstract: "We present a new proximity test for Reed--Solomon codes that admits a higher-agreement regime with soundness approaching the field's bit length." and "The same technique proves soundness of Polygero, a Ligero-inspired IOP [AHIV17], beyond the unique-decoding regime." Also "It does not require roots of unity in the finite field or out-of-domain sampling." and "every reported parameter schedule are machine-checked in Lean." No zero-knowledge claim appears in the abstract. Cycle 1's own wording (a polynomial-challenge proximity test) was right; the loose phrase came from the relay. https://eprint.iacr.org/2026/2481 |
| 2d | arXiv 2606.25453 | "EmuGEMM", 81-83% of INT8 peak | CONFIRMED | "EmuGEMM: Fused Tensor Core Kernels for Precision Emulation in Matrix Multiplication", Lu, Maeder, Luisier, Ziogas. Abstract (tool summary): "With Scheme I, EmuGEMM reaches 83% of INT8 peak on Hopper (1,639 Top/s) and 81% on Blackwell (3,654 Top/s)." Targets Ozaki schemes (high-precision GEMM from integer tensor-core products), on Hopper and Blackwell. It is not a modular-arithmetic kernel. https://arxiv.org/abs/2606.25453 |
| 3a | WHIR 63 KiB at 2^22 | 63 KiB, 2^22 | CONFIRMED | Abstract: "if we use WHIR to construct a polynomial commitment scheme for degree 2^22, with 100 bits of security, then the time to commit and open is 1.2 seconds, the sender communicates 63 KiB to the receiver, and the opening verification time is 360 microseconds." (The tool rendered the exponent as "222"; read as 2^22.) Authors Arnon, Chiesa, Fenzi, Yogev. https://eprint.iacr.org/2024/1586 |
| 3b | WHIR zero knowledge | none | CONFIRMED that the abstract makes no ZK claim | The abstract does not mention zero knowledge. Absence in the abstract does not prove the paper has none; the body was not read. |
| 3c | Ligerito 255 KiB at 2^24 | 255 KiB, 2^24 | CONFIRMED | "Ligerito: A Small and Concretely Fast Polynomial Commitment Scheme", Novakovic and Angeris. Tool returned proof size at 2^24 as 255 KiB; the abstract says "On an M1 MacBook Pro with 2^24 coefficients over a 32-bit binary field, the Julia prover takes 1.3 seconds." The page did not give the 255 KiB sentence as a quote, only as a value. https://eprint.iacr.org/2025/1187 |
| 3d | Ligerito zero knowledge | none | CONFIRMED that the abstract makes no ZK claim | Abstract and keywords do not mention zero knowledge. Body not read. |
| 4 | Thaler 2013 matmul sumcheck overhead | 1-2% of the matmul | CONFIRMED, with a range | Paper Table 5 (matmul protocol of Theorem 3), https://ar5iv.arxiv.org/html/1304.3812: 2^10 x 2^10, naive "2.17 s over Z; 9.11 s over F_q", "Additional Time for P" 0.03 s, V time 0.67 s, 11 rounds. That is 1.4% over the integers and 0.3% over the finite field. 2^11 x 2^11: 18.23 s over Z, 0.13 s additional (0.7%). Text: "the runtime of the prover is hugely dominated by the time required simply to compute the answer." The column counts only time to compute P's messages after the answer is known. Theorem 3: prover time T(n)+O(n^2). So "1-2%" is the upper end; 0.3-1.4% in the table. See note C. |

Counts: 14 line items checked (1a-1e, 2a-2d, 3a-3d, 4); 13 CONFIRMED (three with caveats noted), 1 CORRECTED (2c, a description, not a withdrawn citation), 0 COULD NOT VERIFY.
No identifier was wrong. No citation needs withdrawal.

## Notes

**A. Window and hidden set.** The README says the weights "stay secret: every published value that depends on them is masked,
except a declared list" (`docs/what-is-not-hidden.md`, not read this cycle). Cycle 1's statement that prompt and reply are
public and intermediate values and routing are hidden was not re-read here; cycle 2 took it from the paper. Not re-checked.

**B. How to quote 71-93x.** Three qualifiers are on the same page and should travel with the figure:
- 93.0x is against vLLM at the highest load tried; 71.4x is against vLLM prefill of 24 requests at once.
- The page labels the ratios "a best case: start-up and committing are not counted."
- The vLLM baseline ran the model's FP8 release on eight H100s, in separate untimed runs, and the page says "a baseline that is
  too low flatters the prover." Both ratios are per GPU.

**C. Thaler's range, and the general-circuit contrast.** The same paper's general circuit protocol (Theorem 1, 512 x 512
matmul, Table 1) took 37.85 s against 1.53 s unverified (integers); the text says "our prover runs approximately 25 times
slower than a standard unverifiable matrix multiplication algorithm" (about 8 times over the finite field). The 0.3-1.4%
figure belongs only to the special-purpose matmul protocol, which is interactive, has no commitment and no zero knowledge.
Cycle 3 already stated those limits. The relayed 1-2% should read "0.3-1.4% (table range), interactive, no commitment,
no ZK". Cycle 3 took this figure from a slide table; Table 5 of the paper confirms the same cells (2.17 s, 0.03 s, 0.67 s).

**D. Not verified this cycle (outside the priority list, so not touched).** TensorZKP's 11.58 ms encoder and 4.04 ms
sumcheck at 2^25, its field and its hardware; the FlashProve proof-of-work bit totals (126.2 / 96.2); zkLLM, NANOZK,
Orion and other rows of cycle 3's §1.1; the 5090 figures. Cycle 3's list of "re-check before quoting" items names
zkLLM's 160 kB / 713 s and Orion's 5.7 MB at 2^25; they remain unchecked.

## Status

New full-stack proofs, passes and proved positions: **0 / 0 / 0**. The complete private 8B at >= 50 proved tokens/s on an
RTX 5090 remains **unachieved**. No hypothesis added; no figure in a ranking changes.
