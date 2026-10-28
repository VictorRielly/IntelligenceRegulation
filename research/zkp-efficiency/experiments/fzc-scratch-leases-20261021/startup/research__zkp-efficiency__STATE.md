# ZKP efficiency explorer — durable state

Cycle 0117 COMPLETE: `20261021T011854Z-d7ab1017`. Checkpoint UTC: 2026-10-21T01:34:28.434635+00:00.
Started 01:18:54 UTC; deadline 01:38:54 UTC. Next cycle no earlier than
2026-10-21T02:18:54Z. AGENDA, prior STATE/FINDINGS/all 727 source records, latest
0116 results, CLAUDE, target, MVP status, decisions and active coordination were read.
Startup copies and hashes are in experiments/fzc-tail-boundary-20261021/startup/.

No proving improvement measured. A research fold-directly-to-packed-output candidate
passes 859 checks / 48 synthetic FZC cases / 160 modeled rounds / 80 boundary cases /
nine controls. The independent 55,423-check audit covers 6,144 schedules and 11 pins.
The census passes 30,720 checks. Default threshold 5 already exists; keep it pending
owner clocks. Illustrative n21/k21/kd23: one fewer launch, 24 KiB fewer logical bytes
and 64 fewer derived folds; same 10.5 KiB copy/sync and 736 MiB minimum arena request.
Thresholds 8/10 increase copy 8x/32x and add Rayon regions. No crossover or memory
peak improvement measured. Tail D2H statistics omit other result channels.

Probe/census/audit: 14.028644/0.350108/0.761975 s;
max RSS 40,632 KiB. Seed 202610210117. One worker,
nice 19, 59s CPU/alarm, 60s parent timeout, 512 MiB AS, <=128 MiB estimated memory.
No native build/GPU/proof. candidate_fold_pack.cuh is UNCOMPILED; handoff:
handoffs/20261021-fzc-tail-fold-pack.md. Main reviews/integrates; no merge here.

13 LIVE queries / ten primary records append 727 -> 737. Current Chimera/CMU/ICICLE/
Efficient Sumcheck refreshed; older 2019 CUDA Graphs source newly screened. Commit
429 and license/PDF failures retained without bypass. 34 hypotheses preserve all 31
prior entries and negatives; top four priorities unchanged. Tested tail is rank 13.

Next local experiment: count recurring FzcMapped/PinBuf allocation and mapping
calls per slot attempt, including the fallback PinBuf allocated even when mapping
succeeds. Test an independent lease/sequence oracle across changed degree/support,
shrink/grow, failure, stale matching sequence and incomplete device work. Reuse only
storage; preserve fresh contents, challenges, masks, openings and every fallback.
No native adapter or runtime saving is justified until owner phase evidence supports it.

Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident 1/2/4/8 workloads, fidelity/refusal fixes and the
all-eleven FZC native A/B under shared heavy/build locks.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research ran on one Intel Core Ultra 9
185H CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration and fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic table
lengths 2–2,048 and modeled cube logs 1–26 are diagnostics, not model context lengths.
Larger workloads remain allowed; increasing context can raise attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Historical CPU diagnostic, carried without rerun or reverification: non-DD 8B,
T128, 32 layers, one 16-thread CPU pass, GPU off. Total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s and load 17.595 s. Seal 84.824 s contains
overlapping work. Receipt: 922,711,264 B. Fresh verify: 42.709 s + public load 13.681 s;
recheck: 34.395 s + load 10.739 s. Isolated serialization, startup fraction and steady
slope are unknown. This is not a high-end GPU baseline.

D32/D37 and narrow D33/D36 acceptance were read; preserve D30 N-r9-a/b and DD privacy
review. No 8B/GPU/DD/new-fidelity acceptance inferred.

Only research files outside runtime/ were written. No production, reviewer,
instruction, calibration, Git or receipt edits; no native build, GPU job, installation,
downloaded-code execution, external write/message, purchase or escalation. Main/Claude
reviews and integrates. Saved reports do not establish delivery or supervisor liveness.

Evidence integrity: 213 checks PASS; 54 artifact hashes and 11 source pins match. All 727 prior source records, the prior findings prefix and all 31 prior hypotheses are preserved. No concurrent source/document changes observed. Final audit UTC: 2026-10-21T01:35:13.986602+00:00.
