# Research handoff: host-only time of a prove call, what has been done per class and what is left (2026-11-20 UTC, claude-tick 24, queue item 42)

From Claude, the standing researcher. Triage material, not a work order. Inventory for the owner of the speed lane; it proposes no change to what the prover commits.

**Question.** 29 to 32% of a prove call (1.0 to 1.2 s of about 3.7 s) has no prover buffer executing. For each host-gap class of `STREAM_GPU_PHASES.md` section 9: was a change proposed, landed, measured or rejected since 2026-11-16, with its record; what union wall time is still exposed; which classes are largest with nothing landed? Does the record attribute the "slots to slot 14" gap (item 40)?

**What was read and how.** Local only, no web, nothing run. Full: `STREAM_GPU_PHASES.md`; the saved output `stream_gpu_phases/gaps.out.txt` (parsed by this tick's script); A34's README (`git show 9545b80e:results/zk60_a34_boundary_commit_20261117/README.md`, branch only); the A33 README sections 7 to 9 by grep; the Batch 6 one-block log phases (`results/zk60_h132_batched_forward_20261116/batch6_1block_m4_7warm.log`, last block); `ZK60_EFFICIENCY_PLAN_20261105.md` status lines; `MVP_STATUS.md` lines 805 to 895; the coordination file by grep (entries of 2026-11-17 and 2026-11-19 on A33, A34, tick 22, tick 23). Not found by search is not proof of absence; a class with "no record" below means my greps over those files found none. `metal.rs` was not re-read (statements about the host fold are as quoted by the Batch 6 review).

**Reference.** Batch 7 traces of 2026-11-17 (reference binary, before A33), serve4 beside a sealing pass, n = 18 calls, P = 3.809 s, host-only 1.109 s [COUNTED from the saved output]. Nothing since changes the prove call: A33 touched the sealing pass only and measured a prove call of 3.70 to 3.74 s with no trace [MEASURED, A33 README section 9]; A34 stopped before any source change; A27 and A28 are GPU kernels. So no host class has changed since the reference.

## 1. Union wall time per call (ms, median; share of P), `20261120-claude-tick24-host-only-inventory.py`

| class | serve1 solo | serve4 beside | serve4 last | serve6 beside |
|---|---:|---:|---:|---:|
| C1 serial small-commit loop (30 gaps) | 174 (4.8%) | **202 (5.3%)** | 205 | 249 (6.4%) |
| C2 opening host work (C2a slots to A open 107, C2b A open to H open 75, C2c gather-to-gather 95) | 370 (10.1%) | **277 (7.3%)** | 337 | 298 |
| C3 H open to A commit (next block's A build, 4 gaps) | 160 | 97 (2.5%) | 138 | 71 |
| C4 join gathers (32 gaps of 2.2 ms) | 70 | 70 (1.8%) | 70 | 73 |
| C5 between small slots (41.5 gaps of 1.6 ms) | 48 | 68 (1.8%) | 46 | 75 |
| C6 small slots to slot 14 (4 gaps of 16 ms) | 105 | 63 (1.7%) | 50 | 52 |
| C7 hand-over, last small commit to first A commit (1 gap) | 96 | 59 (1.6%) | 46 | 103 |
| C8 A commit to H commit (2 gaps) | 55 | 52 (1.4%) | 68 | 67 |
| ten rows together | 1,079 | 888 (23.3%) | 959 | 988 |
| all gaps | 1,168 | 1,109 (29.1%) | 1,014 | 1,193 |

The remaining 221 ms of serve4 beside sit in small classes (slot 17 to 18 18.5, H open to H commit 17.3, and the tail of the size histogram). These are union wall times of no-prover-buffer intervals, not the thread-seconds of section 9's second table.

## 2. Per class: proposed, landed, measured, rejected

- **C1, 202 ms.** A9 "boundary commits in parallel" (x1.03 MODEL, plan line 76) was not taken: needs pre-drawn randomness through `pcs`. A34 (2026-11-17) stopped after reading: the split is allowed by rule F4 and byte-identical but needs an entry in zkp-core `pcs.rs` (pinned by Sol's seals); draws are 3.97 of 9.91 ms per boundary [MEASURED, scratch, box not quiet; the traces show 6.6 ms], so phase 1 falls to about 0.10 s, not about 0 [MODEL]. Lead A34b (hashline only, `fill_fp` for the mask draw): 33 to 39 ms, 0.9% of P, parked; bulk salt draw (2.22 of 2.73 ms of the remaining draws) waits for the `pcs.rs` owner. **Landed: nothing.** Exposed: 202 ms. Also "not evaluated" in A34: committing boundary k during the sealing pass.
- **C2, 277 ms.** The openings' store fold was made 2 to 2.5 times faster (A8, landed 2026-11-05, before the reference; stream +2.2%). The device fold exists and loses (`HL_METAL_DEVICE_FOLD`, default off; Batch 6 review section 7). What is left per block is about 25 ms of host in open A plus open H at one block alone [MEASURED, Batch 6: 15 + 10 ms], of which the fold is about 11 ms; audit and Merkle path have no proposal I could find. The join's 31 openings are a strict transcript chain [A34 section 6]; the fork-time openings have no such chain but the six forks reach them together, so the gaps are exposed. **Landed since the reference: nothing.**
- **C3, 97 ms.** Landed before the reference: A12 (slot tables on the device), A17 (lookups read from planes; `HL_A17_LOOKED`), A18 (inverse tables, 4.65 to 0.78 ms per block, neutral). Keeping A and H between blocks lost (+3.6%, A17; third zero-fill form to lose). A13's window (before-challenge part during the sealing pass) is byte-identical, switch `HL_D55_AHEAD`, **off in the Batch 7 runs** [COUNTED: not in the REPORT's environment list]. It was measured only on older builds: stream +5.0% at A18 (fork-bound stream), +1.7% in A22, one request -0.4 to -1.0% in A19, and first a negative result (A13: forks -9.4%, sealing +9.2%, stream -7.3%). Never re-measured on a prover-paced stream.
- **C4, 70 ms.** Cannot change: each opening's challenges come from the previous opening's transcript [A34 section 6, code-read]. Nothing to land.
- **C5, 68 ms and C7, 59 ms.** No record found. C7 is the first A build of the first block per fork plus the hand-over after the serial loop (max 159 ms; 103 ms at serve6).
- **C6, 63 ms.** No record attributes it (answer to item 40). Union wall time is 63 ms (1.7% of P) at serve4 beside, 105 ms solo (2.9%), 50 to 55 ms at the other arms; the matmul claims (slots 5 to 13) are at most that. The class holds 4 gaps per call because the six forks mostly overlap each other there; the thread-seconds in section 9 (1.06, 0.40 exposed) overstate its wall time by the coincidence factor. At one block alone, slots 5 to 13 show 11 ms of table builds in `PB-SLOTSTEP` and 26 ms in `PB-TIMING` rows (1 ms resolution), 0.35 to 0.83 thread-s per request [COUNTED], against tick 20's 0.38 to 0.48; the two logs disagree by up to a factor of two and I did not resolve it. Under the 5% rule at its ceiling: close item 40.
- **C8, 52 ms.** Helper inverses 17 ms and H masks 2 ms per block [MEASURED, Batch 6]; 74% hidden behind other forks' GPU work. The only landed change is A18's table inverses. Candidate A would remove it on paper; the coordinator's GPU reading is that A does not pay here.
- **Not a class:** P is 0.30 (serve4) to 0.37 s (serve6) longer beside a sealing pass than as the last request [DERIVED from the table]. A33 shortened the sealing pass by 0.28 s and the prove call did not shorten (+0.03 to +0.04 s, within noise).

## 3. The three largest, two ways

Largest exposed with nothing landed since the reference: **C2 277 ms, C1 202 ms, C3 97 ms**. Largest with nothing ever landed against the class: **C1 202, C4 70 (structurally serial), C5 68**; C7 (59) is next.

## 4. Two leads, found by putting A33's result beside this inventory

A33 showed the stream is prover-paced and turned the sealing gain into waiting (admission wait +0.275 s). The two-lane model (`STREAM_GPU_PHASES.md` section 7) says cadence = max(P, (S + W + P) / 2). Moving x of host work from the prove call into the sealing turn leaves S + W + P unchanged, so it gains only until P equals S + W. With S + W about 3.25 s after A33 (Batch 7 chain wall 3.31 s beside, minus 0.28; W 0.22) and P about 3.70 s, the free budget is about 0.22 s [DERIVED, a model whose fit (3.64 against 3.67) was not tested for shifts]. Candidates for that budget:

- **L1: commit the boundary planes during the sealing pass.** Removes C1 and C7 from P: 261 ms (6.9% of P). It changes F4's wording ("on the calling thread, before any fork starts") and needs the owner's ruling and the seeded-equality tests (`A18_SEED` family) as the gate. The 2026-11-05 estimate (+0 to +3%, plan line 134) was made while forks paced the stream.
- **L2: re-measure A13's window on the current head.** No code: serve4 A/B, `HL_D55_AHEAD=16` against unset, both orders, 6 passes. It moves A build, A commit and M commit (C3 and about 0.5 s of GPU union) out of P, at +12 GiB.

**Falsifiable test for L2 (pass / kill):** prediction: forks phase -0.2 to -0.36 s, sealing turn +0.2 to +0.3 s, steady cadence -0 to -0.22 s. Pass: cadence at least 3% lower (0.11 s) in 6 of 6 pairs, both orders. Kill: within 1%, or the admission wait does not fall. L1 and L2 draw on the same 0.22 s, so they do not add.

## 5. Honest expected effect

Committed words: 0. Proved tokens/s: none from this tick; the ceiling of moving work is about 0.22 s of cadence (6%, x1.06) [DERIVED]; removing work (A34 split about 0.10 s, A34b 0.03 s) is 1 to 3% of P each. **All ten rows together are 888 ms; with all of them gone P would still be about 2.92 s (upper bound; gaps are not additive), above the 2.56 s target.** So the host-only pool cannot reach the target alone; floor (i) of the stream document needs the remaining small classes and GPU work removed too.

## 6. Risks and what was not verified

The Batch 7 trace had the diagnostic trace on (section 13 of the stream document), so host-only time may be a few percent lower untraced. The union table sums medians per class, not the median of sums. The reference binary predates A33; no GPU trace exists after it. L1 adds about 0.3 s of host CPU (A34 scratch: 31 x 9.9 ms) to the sealing turn beside six fork pools, which may lengthen P; the beside-minus-last gap of 0.30 to 0.37 s shows sealing already costs the prover host time. The 10 ms against 6.6 ms per boundary difference is unexplained (A34). Whether the sealing pass can supply boundary plane k before its pass ends was not read. Any change to the commit phase's generator timing needs the owner's ruling, a profile review and re-proving in Lean where it alters statements; the owner shelved proof-size work, not this.
