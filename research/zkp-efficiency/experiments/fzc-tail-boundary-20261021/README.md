# FZC CPU-tail boundary study — cycle 0117

Run `20261021T011854Z-d7ab1017`. Checkpoint: 2026-10-21T01:34:28.434635+00:00.

**No proving speedup measured.** The active GPU FZC code already switches late
sumcheck rounds to the CPU at a default threshold of 32 entries. The tested candidate
folds the original tables directly into the packed download buffer. It could remove
one boundary kernel and avoid folding derived tables that the host no longer uses.

For the illustrative n=21, k=21, kd=23 case at threshold 5, the count model changes
18 body/tail kernel launches to 17 and removes 24 KiB of logical device traffic and
64 derived Fp2 fold outputs. It retains the 10.5 KiB copy, pinned buffer, synchronization
and host polynomial/fold work. The minimum device-table request stays 736 MiB until
the evaluator drops; pooled capacity may be larger. No actual VRAM peak saving follows.

Increasing the threshold from 5 to 8 or 10 changes the copy from 10.5 KiB to 84 or
336 KiB, host pair evaluations from 31 to 255 or 1,023, and Rayon regions from 0 to
1 or 3. It can also disable raw-source construction for small cubes. These counts
establish no crossover time. Keep threshold 5 until the owner measures the tradeoff.
The existing bytes_d2h counter records only the tail copy; mapped round messages
still write system memory, while normal fallback and final copies are counted elsewhere
in this study. Moving computation to the host does not release the device arena.

Baseline: k_sc_fold over kd tables followed by k_fzc_pack over the original k tables.
Removed work: one launch, intermediate stores/rereads and unused derived folds at this
boundary. Added costs: a small kernel, module registration/cache rebuild and native
validation; allocation, copy and synchronization costs remain. With unknown exclusive
boundary fraction f, even free removal gives only a total speedup bound of 1/(1-f).
This candidate removes part of that fraction. No numeric full-proof rate is supported.
Falsify it on any canonical round, next challenge, final, receipt or refusal mismatch,
stale/raw read, later use of a derived table, device failure or enclosing-time regression.

The probe passes 859 checks across 48 actual-FZC synthetic cases (160 modeled
rounds), 80 fold/pack boundary cases and nine controls. The original 20/21 table order,
MSB pairs, both Goldilocks Fp2 coordinates and all eleven geometric pad powers are
retained. The independent audit passes 55,423 checks over 6,144 schedules,
11 source pins and six controls. The census passes 30,720 checks.
Probe/census/audit clocks are 14.028644 / 0.350108 /
0.761975 s; maximum RSS is 40,632 KiB.
Seed: 202610210117. Every experiment used one worker/core, nice 19, a 59-second
CPU/alarm limit, a 60-second parent timeout and 512 MiB address-space limit;
estimated memory <=128 MiB. No native build, GPU kernel, masker, transcript, PCS,
receipt or verifier ran. Synthetic challenge-chain hashes are not native proof hashes.

Thirteen LIVE queries produced ten primary-source records (727 -> 737). The search
refreshed Chimera's October 16 revision, the September 1 CMU sumcheck article,
ICICLE's latest v4.0.0 release/adapter and Efficient Sumcheck. NVIDIA's September 5,
2019 CUDA Graphs article is a newly assessed older lead: replay can reduce submissions
inside one fixed segment, but fresh host-derived challenges prevent blind replay
across rounds. Native default rounds already use one fused split kernel. Graph setup,
parameter updates and buffer lifetimes must be charged before considering that route.
ICICLE's current MIT license body and release commit
6c77775961b0e4dc2be359feec1ac11536c18043 were inspected. Efficient Sumcheck's commit
page returned 429; other license/PDF cache/access failures are recorded without bypass.
No upstream code or author benchmark was executed. The queue has 34 ranked hypotheses;
all 31 prior entries and negative findings remain, and the top four owner priorities
are unchanged. The tested tail candidate is rank 13; graph replay and scratch leases
are ranks 33 and 34.

## Reproduce

Run sequentially from the research directory:

`python3 experiments/fzc-tail-boundary-20261021/run_bounded.py probe.py`

`python3 experiments/fzc-tail-boundary-20261021/run_bounded.py census.py`

`python3 experiments/fzc-tail-boundary-20261021/run_bounded.py audit.py`

commands.jsonl retains launches, limits and exit codes. reference.py is the pinned
independent schoolbook field/original-slot oracle. audit.py imports no producer or
scheduler implementation. source-pins.json separates root and active GPU-lane files.
The uncompiled candidate is candidate_fold_pack.cuh. The actual Rust/CUDA seam and
owner validation requirements are in the handoff. Source counts are not instructions,
DRAM measurements, native launch observations or timings.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research ran on one Intel Core Ultra 9
185H CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration and fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic table
lengths 2–2,048 and modeled cube logs 1–26 are diagnostics, not model context lengths.
Larger workloads remain allowed; increasing context can raise attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Next local experiment: count recurring FzcMapped/PinBuf allocation and mapping
calls per slot attempt, including the fallback PinBuf allocated even when mapping
succeeds. Test an independent lease/sequence oracle across changed degree/support,
shrink/grow, failure, stale matching sequence and incomplete device work. Reuse only
storage; preserve fresh contents, challenges, masks, openings and every fallback.
No native adapter or runtime saving is justified until owner phase evidence supports it.

Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident 1/2/4/8 workloads, fidelity/refusal fixes and the
all-eleven FZC native A/B under shared heavy/build locks.

Only research files outside runtime/ were written. No production, reviewer,
instruction, calibration, Git or receipt edits; no native build, GPU job, installation,
downloaded-code execution, external write/message, purchase or escalation. Main/Claude
reviews and integrates. Saved reports do not establish delivery or supervisor liveness.
