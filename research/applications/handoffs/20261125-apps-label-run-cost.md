# Cost of n single-category policy runs against a multi-token label (A18)

**Question.** For n = 4, 8 and 16 registered policies on one input: what do n separate runs cost, what shared-prefix saving do the records support, and what does the label side cost (a k-token label, or a one-position choice among n label tokens in place of the two-way margin), including its effect on the D32 calibration? Local counting only; nothing was run. Arithmetic: `20261125-apps-label-run-cost.py` (reads files, prints; output `20261125-apps-label-run-cost.out.txt`, which first re-checks every input against its line).

**Answer in one line.** n separate runs cost n times 2.56 to 2.72 s of six-lane stream capacity and n times 669,561,472 bytes (n = 16: 41.0 to 43.5 s, 10.7 GB), and the records support no shared-prefix saving. A k-token label read in one pass fits inside the padded window for most item lengths, so it is not k runs; but no time exists for any label relation at the installed profile, and the records only support a count argument that a restricted n-way choice is small beside a run. It must be spiked, not assumed.

## What was read and how

`MVP_STATUS.md`, the lane-threads README, Astra's `PILOT.md`, the Shieldstral privacy statement v3, the token-I/O design `results/zk60_token_io_design_20261017/DESIGN.md`, the app's template code (read only), `20260926-kv-proof-state.md`, and the A10 and A13 handoffs. No web. No timing comes from the block test (diagonal weights).

**Profiles.** Stream rates and receipt size: installed W16R2 Shieldstral profile, trained 3B weights, 26 blocks, T = 128, six lanes, per-thread queues (`w16r2_runtime.py:104`: eight threads a lane). Per-stage byte figures (section 4) are the older R13 Shieldstral profile and are sizes, not times. Design counts are Llama-3-8B, not the classifier.

## 1. n separate runs (DERIVED: 128 padded positions divided by a stream rate)

One run is one chunk window under one policy: 128 padded positions [`shieldstral_text.py:86, 114-115`], 669,561,472 B over 28 segments [MEASURED by Astra, `PILOT.md:15`]. Each column is a different timing set of the lane-threads record; the columns are not ranked and no cause is given for their differences.

| n | receipt | set A: 6x5, 47.11 tok/s (`README:83`) | set B: 6x8, 48.64 (`:85`) | set C: 6x8 default arm, 48.96 (`:110`) | set D: 6x8 tail-250 arm, 50.00 (`:110`) |
|---:|---:|---:|---:|---:|---:|
| 1 | 0.67 GB | 2.72 s | 2.63 s | 2.61 s | 2.56 s |
| 4 | 2.68 GB | 10.87 s | 10.53 s | 10.46 s | 10.24 s |
| 8 | 5.36 GB | 21.74 s | 21.05 s | 20.92 s | 20.48 s |
| 16 | 10.71 GB | 43.47 s | 42.11 s | 41.83 s | 40.96 s |

Stream-capacity seconds, not one input's latency (not derived). A post of J chunks multiplies by J (3 to 22 at T = 128, statement v3 lines 63, 205). Rates [MEASURED by the coordinator, one machine]; table [DERIVED].

## 2. Shared-prefix saving: none supported

The template is policy text first (BOS id first), then the content chunk, the one-token suffix and pad ids to 128 [`shieldstral_text.py:76, 114-115`]; policy lengths are 72, 72 and 78 tokens [statement v3 line 204]. Two policies share one token. Content-first would be a new template with its own calibration (`config.py:75-78`). The records hold no mechanism or measurement either: KV reuse is not authorized and a K/V-only check changed the frozen relation in a synthetic test (`kv-proof-state.md:47-60, 126`); "public-prefix reuse" is an owner line with no figure (`20261030-deepprove-gap.md:105`); every receipt proves all 128 positions, pad rows included (statement v3 line 85). The table carries 0 s of saving, meaning "not measured".

## 3. The k-token label: not k runs, and not a proved chain either

A10's option (b) said k tokens cost "roughly k" forward steps. Two records change that.

- Repeated runs do not prove a label: several tokens from repeated mode-(i) runs are "not a proved token stream", since nothing proves run k+1's input is run k's input plus its output and joining finished runs is forbidden by D12a (`DESIGN.md:479-483`). k times 2.56 to 2.72 s buys no proof of the sequence.
- The designed route is one pass: label tokens sit in the window after the suffix, the head is read at k positions, and a shift check ties each token to the preceding argmax (`DESIGN.md:465-474`, "mode (ii)", not built; D78 puts a token-I/O profile into W16R3). The 26 blocks are unchanged, as pad positions are already proved. DERIVED room, item_length = P0 + n + 1: P0 = 72 with a 40-token input leaves 15 spare positions (k up to 16); P0 = 78 leaves 9 (k up to 10); a full chunk (55 or 49) leaves none, so a k-token label shrinks the chunk by k-1.

The cost moves to the head stage. The only counts are the design's Llama-3-8B full-vocabulary argmax: 2.769 M committed elements for one position (0.098 of a T32 block, 28.3 M) and 285.7 M for 128 positions [COUNTED, `DESIGN.md:520, 532, 721`]. A label restricted to registered ids would use narrower planes; no count exists. The prefix-consistency result behind one-pass teacher forcing was measured on TinyLlama only (`DESIGN.md:475-478`).

## 4. The one-position choice among n label tokens (n-way in place of the margin)

Today: a public margin vector (difference of two tied embedding rows) dotted with the final-norm output at one row, compared with a threshold; tau = 0.5 gives threshold 0 [`config.py:72-73`; statement v3 line 203]. An n-way choice needs n-1 difference vectors against the chosen token, each non-negative, and a registered tie rule.

- Raw multiply-adds: 3,072 per difference vector, 46,080 for n = 16, 1.2e-7 of the window's 3.9e11 for the block projections and feed-forward (DERIVED from the dimensions, statement v3 line 201). **Not** a proof-time figure.
- Closest record: at R13, stage OUT-C is 7,161,056 B against 118,593,824 B for one block (0.060) and 848,412,096 B for the receipt (0.0084) [statement v3 lines 476, 202; bytes, older profile]. No per-stage size or time at the installed profile was found.
- **Correction, 2026-11-25 (co-coordinator, after Sol's study A21):** the 7,161,056 B in the line above is not a size. Statement v3 line 476 gives it as the bytes a seeded generator draws for the stage (mask randomness), beside 118,593,824 B drawn for a block. The two ratios 0.060 and 0.0084 are withdrawn as size shares. The retained R13 records give the output stage's frame as 3,292,120 B of the 848,412,096 B receipt (0.39 percent); see `20261125-apps-restricted-head.md`. The script beside this handoff still prints the old reading.
- ESTIMATE (reasoning, unmeasured): for n up to 16 the added planes are small beside the stage's fixed geometry, so the label side would be a small part of a run and cheaper than n runs. This is the kind of guess that needs the count below before anyone plans on it.

Public information: n separate yes/no policies publish n bits per chunk; one n-way choice at most log2 n (4 for n = 16) [DERIVED; statement v3 line 103]. A privacy-statement change, not a free saving.

## 5. Effect on calibration (D32)

D32 (`ZK60_DECISIONS.md:61`: perplexity at most 1.02 times the float model, LAMBADA at least 98 percent, zero refusals) concerns the 26-block stack, which an n-way head does not change. What changes:
- No single threshold: today one tau per policy sets the operating point; n-way has an argmax and a tie rule, so per-label trade-offs need registered public offsets (a proposal, not in the records).
- More near-ties: the integer head matched the float head on 100 percent of positions with a float top-two margin of at least 0.3 logits and 98.9 to 99.8 percent overall, every miss a float near-tie [MEASURED by the fidelity lane, per-row int8 head at 8B, full vocabulary; `DESIGN.md:358-360`, `MVP_STATUS.md:3735-3737`]. More labels mean more close competitors; no agreement figure exists for any label set, nor for the two-way classifier at the installed profile beyond six matched margins (`MVP_STATUS.md:25`).
- New refusal sites for a logit-difference range (statement v3 lines 120-131: real-post refusal rate not measured). A label set is a new policy id with a fresh calibration.

## What a product would have to build

A registered label set (token ids, tie rule, offsets); the n-way head relation with its Lean statement; for k-token labels, the mode-(ii) shift check and a chunk plan leaving k-1 positions; a held-out calibration of integer against float choices.

## A test that would confirm or kill the finding

1. Count (no GPU): extend the design's counter (`token_io_count.py`) to a restricted n-way stage at n = 2, 4, 8, 16 and compare with the two-way OUT-C counts. **Confirmed** if the A/H rows and the 2^12 geometry do not grow (receipt change under 1 MB); **killed** if it needs vocabulary-wide planes.
2. Only after 1 passes: one timed spike at six lanes in one session, arms interleaved, base over variant.
3. Calibration: public held-out items, integer against float choice, report the share with float top-two gap under 0.3 logits per label set.

## What was not verified

Any time for stage OUT-C or an n-way stage at W16R2; W16R2 stage byte sizes; the single-post latency of n runs; whether the installed policy lengths equal the R13 statement's 72, 72, 78 beyond the policy ids in the tests; and whether any buyer needs n above 3 (A17 asks the demand side).
