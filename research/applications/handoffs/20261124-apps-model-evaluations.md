# Receipts for a score on a hidden benchmark

A benchmark owner could publish “the pinned integer model answered K of the N committed questions correctly” while keeping the prompts, answer key and individual predictions private. The current trained 8B proof reaches the next-token decision on a held-out prompt. A public verifier still needs a link from every benchmark row through its inference proof to the reported score. No run in the records reviewed demonstrates that complete claim. [Project status](../../../docs/zkmatrix-poc/MVP_STATUS.md) · [Privacy requirements](../../../docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md)

## What the trained model already proves

[MEASURED, one guarded CPU run] On a held-out 128-token prompt, the W16R3 refit linked the input-token lookup through 32 trained layers, final normalization, full vocabulary head and greedy token choice. A fresh verifier accepted 34 segments at a reported 97-bit floor. The input owner confirmed the prompt and the output owner matched the selected token to an independent integer calculation. A later CPU run on the same prompt exercised the exact sampler. The complete 8B verifier view still awaits privacy acceptance. An earlier accepted next-token privacy statement applies to a named TinyLlama T32 profile. [Held-out validation](../../../results/zk60_sol_20261105_w16r3/b3/D78_TRAINED_8B_HELDOUT_VALIDATION_484.md) · [Exact sampler run](../../../results/zk60_sol_20261105_w16r3/b3/D78_TRAINED_8B_EXACT_DRAW_VALIDATION_502.md) · [TinyLlama statement](../../../docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md)

[MEASURED, numerical evaluation] The same refit's integer reference scored 158/200 on LAMBADA, versus 156/200 for float. Its D32 audit also identified three calibration overlaps in the other corpora. The held-out native receipt authenticates one selected FineWeb prompt. The LAMBADA numerator comes from the numerical evaluation. A benchmark receipt would have to authenticate that numerator independently. [Quality, overlaps and prompt selection](../../../results/zk60_sol_20261105_w16r3/b3/D78_TRAINED_8B_HELDOUT_VALIDATION_484.md)

## Cost of 1,000 prompts

Assume one padded 128-position prompt and one greedy decision per question. These are capacity calculations for distinct profiles.

| Recorded measurement | Derived cost for the assumed workload |
| --- | --- |
| [MEASURED] 40.2 padded positions/s, synthetic 8B transformer stack on the Mac, two lanes, fused encoder and sparse fold, steady stream. | [DERIVED] 1,000 × 128 ÷ 40.2 ÷ 60 = **53.1 minutes of stack capacity**. Startup, trained token endpoints, scoring and verification would need their own timing. [Stream measurements](../../../results/zk60_composed_8b_20261123/README.md) |
| [MEASURED] On the trained held-out CPU run, 487.299 s to prove and 32.061 s to verify, measured inside the tools. Receipt size 772,144,912 bytes. | [ESTIMATE from one prompt] At that cost for each row, serial proving takes **135.4 hours**, independent verification another **8.9 hours**, and retaining every receipt takes **772.1 GB** decimal. This excludes owner checks, dataset handling and the aggregate proof. [Trained run and timing](../../../results/zk60_sol_20261105_w16r3/b3/D78_TRAINED_8B_HELDOUT_VALIDATION_484.md) |

## What a product has to bind

- Freeze the export, calibration, tokenizer, prompt template, input length and padding rules, decoding rule and scorer version. Have the benchmark owner sign and date a hiding commitment to the ordered prompts, gold answers, unique row positions and denominator before evaluation. Version the dataset and disclose the selection rule. Freshness, label quality and prior training exposure need separate evidence.
- Start with single-token exact match. For each row, prove that the input capsule contains the committed token sequence and that the hidden greedy output equals the gold token exactly when its score bit is one. Count off-format predictions as wrong and define refusals in advance. A ranking over answer choices needs its own scoring rule. Free-form answers need successive token proofs, a stopping rule and an authenticated grader.
- Prove that the sum includes every committed position exactly once, under the same model and rules, and release the numerator and denominator. Owner checks currently require private openings. An auditor needs a publicly checkable equivalent that keeps the openings private. The benchmark owner can host the prover for public weights because the prover reads the prompts. Confidentiality from a separate model or proving operator requires an additional trust arrangement. Repeated or overlapping published scores can disclose individual outcomes.

## Published precedents and a deciding test

Tobin South and colleagues demonstrated verifiable performance attestations with fixed private weights and public test inputs. Tanmay Rajore and colleagues published TRUCE for private benchmarking, including confidential-computing and cryptographic options when the model and dataset have different owners. The first supplies an example of binding performance to weights. The second addresses who can see the questions during evaluation. Both were read as published research. [South et al.](https://arxiv.org/abs/2402.02675) · [Rajore et al.](https://arxiv.org/abs/2403.00393)

For a first test, precommit a small unseen set with a correct answer, a wrong answer and an off-format prediction. Keep a private reference score. An independent reader with only public artifacts must recover the same numerator and denominator and reject an omitted row, repeated position, swapped answer key, substituted export and altered count. Inspect all public artifacts for prompt, answer and prediction disclosure. Measure proving, verification and receipt bytes separately before attempting 1,000 prompts. No hidden-set aggregation, fresh hardware run or 8B privacy qualification was performed for this handoff.
