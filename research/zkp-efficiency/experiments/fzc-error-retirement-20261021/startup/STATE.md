# ZKP efficiency explorer — durable state

Cycle 0118 COMPLETE: `20261021T021854Z-dc9711cc`. Checkpoint UTC: 2026-10-21T02:33:40.559814+00:00.
Started 02:18:54 UTC; deadline 02:38:54 UTC. Next cycle no earlier than
2026-10-21T03:18:54Z. AGENDA was read at startup and again before checkpoint.
All 737 prior source records and full durable files were parsed/snapshotted;
latest prior results, CLAUDE, target, status, decisions and active coordination read.
Startup hashes and complete snapshots: experiments/fzc-scratch-leases-20261021/startup/.

No proving improvement measured. Storage probe passes 1,418 checks / 96 fixtures /
320 synthetic messages / 36 shape transitions / 17 control types. Source model
passes 24 checks over 120 event interleavings, with zero failures in eight
same-stream/post-sync cases. Independent reviewer passes six checks and matches
changing-shape counts. Probe/census 0.021853/0.019860 s;
maximum parent RSS 16,340 KiB. Seed 202610210118.
One worker/core, nice 19, <=60 s per experiment, <=512 MiB AS, <=64 MiB estimated.
Independent audit <=30 s CPU/alarm and <=256 MiB AS, under one second.

Conditional32-attempt fixed-shape trace: 96 -> 3 host allocations,32 -> 1 map
queries,10,952 B retained. Changing shape:96 -> 6 allocations,513,792 -> 32,112 B
cumulative allocated;21,704 B idle retention and31,944 B transient peak versus
21,704 B baseline. No native allocation/time/VRAM saving measured; d_pack remains.
Only storage reuses, no masks/results/challenges/openings or private preprocessing.
Existing ctor sync is stream-scoped: clear retained storage AFTER successful sync,
provided it covers every prior use. Degree changes move flag offset. Capacity-sized
copy overreads smaller d_sums; use active-length views. Published seq is not last-use
completion. Preserve eager fallback acquisition; identical physical OOM behavior is
not claimed. Timeout drop-before-explicit-sync is a source-level review risk only.

Five LIVE queries / seven primary records appended737 -> 744. Newly screened older
2012 pinned-transfer source; current Chimera/ICICLE/CUDA13.4/Grace-Blackwell refreshed.
NVIDIA sample paths404 retained without bypass. ICICLE MIT body and commit
6c77775961b0e4dc2be359feec1ac11536c18043 inspected; no guessed release year.
34 hypotheses preserve prior entries and negative findings; rank34 refined and
ranks1/2 updated with D32 and concurrent owner evidence. Owner top-four rank order unchanged.
Main/Claude reviews and integrates; no native adapter or merge here.
Handoff: handoffs/20261021-fzc-scratch-leases.md.

Next local experiment: model mapped timeout/error cleanup with an independent
last-use oracle across copy failure, sync failure, context poison and other-stream
access. Distinguish safe retirement from bounded quarantine; never assume
cuMemFreeHost synchronizes. Native owner needs allocation incidence and exclusive/
enclosing clocks before any runtime optimization claim. Preserve current arithmetic,
refusal, fresh masking and fallback behavior.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel Core Ultra 9
185H CPU worker per experiment. Witness, proof, serialization and verification clocks:
**unmeasured**. Startup duration/fraction, steady-state rate and total-workload rate:
**unmeasured**. No long-context prefill, resident-model proof series or decode ran.
The 32-attempt traces are synthetic allocation schedules, not 32 model passes.
Larger workloads remain allowed; longer contexts can increase attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Owner priorities: complete high-end GPU phase/capacity clocks; verified fixed-context
resident 1/2/4/8 workloads; fidelity/refusal work and DD privacy gates; all-eleven FZC
native A/B under shared heavy/build locks. D32 now permits1–2% fidelity degradation,
zero refusals remains. D33/D36 narrow CPU TinyLlama scopes and D30 bindings retained;
D37 classifier application does not change this lane's 8B target.

Historical CPU diagnostic, carried without rerun/reverification: non-DD8B, T128,
32 layers, one16-thread CPU pass, GPU off. Total478.737s =0.267370positions/s.
prove_run393.785s includes witness98.348s and load17.595s. Seal84.824s contains
overlapping work. Receipt922,711,264B. Fresh verify42.709s +public load13.681s;
recheck34.395s +load10.739s. Isolated serialization, startup fraction and steady
slope unknown. This is not a high-end GPU baseline.

Only research files outside runtime/ written. No production, reviewer, instruction,
calibration, Git or receipt edits; no native build, GPU, installation, downloaded-code
execution, external write/message, purchase or escalation. Reports do not establish
supervisor liveness or message delivery. Artifact integrity completed; concurrent owner document updates read.

Checkpoint update, read at 2026-10-21 02:34 UTC: production status and decisions
changed during this cycle. Their complete new text and diffs are preserved under
startup/checkpoint__*. D33 and D36 now extend to frozen-r11 by the register's
02:27 ruling; they remain scoped to named TinyLlama CPU artifacts. D38 records
Shieldstral-1.0-3B text classification and a public-threshold yes/no logit statement,
with only verdict/model/policy disclosed. This application direction does not
replace this lane's private 8B throughput target. The status also reports the first
eight DD gate captures passing (gate evidence, not a new privacy acceptance) and
LOW + 12-bit-score 8B fidelity at 1.011x/1.010x with zero refusals. These are owner
reports, not reproduced here; new profile/gate and complete GPU clocks remain owed.
The status heading labels 02:40 UTC; the actual read time above is retained.

Evidence integrity: 145 checks PASS; 50 artifact hashes and 10 live/source-copy pins match. All 737 prior source records, the prior findings prefix and all 34 hypothesis entries are retained. Concurrent owner updates were read and snapshotted. Finalized UTC: 2026-10-21T02:36:20.454182+00:00.
