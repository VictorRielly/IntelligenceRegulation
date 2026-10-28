from pathlib import Path
import datetime,json
H=Path(__file__).resolve().parent;R=H.parent.parent;run='20261021T011854Z-d7ab1017'
p=json.loads((H/'result.json').read_text());c=json.loads((H/'census-result.json').read_text());a=json.loads((H/'validation-result.json').read_text())
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
clocks='''New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research ran on one Intel Core Ultra 9
185H CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration and fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic table
lengths 2–2,048 and modeled cube logs 1–26 are diagnostics, not model context lengths.
Larger workloads remain allowed; increasing context can raise attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.'''
next_action='''Next local experiment: count recurring FzcMapped/PinBuf allocation and mapping
calls per slot attempt, including the fallback PinBuf allocated even when mapping
succeeds. Test an independent lease/sequence oracle across changed degree/support,
shrink/grow, failure, stale matching sequence and incomplete device work. Reuse only
storage; preserve fresh contents, challenges, masks, openings and every fallback.
No native adapter or runtime saving is justified until owner phase evidence supports it.

Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident 1/2/4/8 workloads, fidelity/refusal fixes and the
all-eleven FZC native A/B under shared heavy/build locks.'''
summary=f'''**No proving speedup measured.** The active GPU FZC code already switches late
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

The probe passes {p['checks']} checks across 48 actual-FZC synthetic cases (160 modeled
rounds), 80 fold/pack boundary cases and nine controls. The original 20/21 table order,
MSB pairs, both Goldilocks Fp2 coordinates and all eleven geometric pad powers are
retained. The independent audit passes {a['checks']:,} checks over 6,144 schedules,
11 source pins and six controls. The census passes {c['checks']:,} checks.
Probe/census/audit clocks are {p['wall_seconds']:.6f} / {c['wall_seconds']:.6f} /
{a['wall_seconds']:.6f} s; maximum RSS is {max(p['rss_kib'],c['rss_kib'],a['rss_kib']):,} KiB.
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
are ranks 33 and 34.'''
limits='''Only research files outside runtime/ were written. No production, reviewer,
instruction, calibration, Git or receipt edits; no native build, GPU job, installation,
downloaded-code execution, external write/message, purchase or escalation. Main/Claude
reviews and integrates. Saved reports do not establish delivery or supervisor liveness.'''
historical='''Historical CPU diagnostic, carried without rerun or reverification: non-DD 8B,
T128, 32 layers, one 16-thread CPU pass, GPU off. Total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s and load 17.595 s. Seal 84.824 s contains
overlapping work. Receipt: 922,711,264 B. Fresh verify: 42.709 s + public load 13.681 s;
recheck: 34.395 s + load 10.739 s. Isolated serialization, startup fraction and steady
slope are unknown. This is not a high-end GPU baseline.'''
report=f'''# Cycle 0117 — FZC tail boundary — 2026-10-21

Run `{run}`. Checkpoint: {now}. Started 01:18:54 UTC; deadline 01:38:54 UTC.

{summary}

{clocks}

{historical}

D32's fidelity bar, D37's classifier direction and the narrow D33/D36 frozen-r9
TinyLlama T32 CPU acceptance were reread. They do not admit 8B/GPU/DD or a new fidelity
profile. Preserve D30 N-r9-a/b and the outstanding DD privacy gate. No ruling was edited.

{next_action}

[Experiment](../experiments/fzc-tail-boundary-20261021/README.md),
[handoff](../handoffs/20261021-fzc-tail-fold-pack.md).

{limits}
'''
(R/'progress'/f'{run}.md').write_text(report)
prior=(H/'startup/FINDINGS.md').read_bytes();current=(R/'FINDINGS.md').read_bytes()
assert current.startswith(prior)
assert b'Cycle0117' in current[len(prior):]
(R/'FINDINGS.md').write_bytes(prior+'\n\n## Cycle0117 — FZC CPU-tail boundary: exact small launch/traffic candidate\n\n'.encode()+report.encode())
(R/'PROGRESS.md').write_text(f'''# ZKP efficiency progress

Cycle 0117 complete — `{run}` — 2026-10-21 UTC.

**No proving speedup measured.** The fused fold/pack candidate passes 48 synthetic
FZC cases and an independent 55,423-check audit. At the default tail threshold, the
illustrative case removes one kernel launch and 24 KiB of logical traffic. The copy,
synchronization and device arena remain. Larger CPU tails add copy and host work;
no runtime crossover is established. The CUDA sketch is uncompiled and low priority.

{clocks}

Next: audit recurring mapped/pinned scratch allocation with sequence/completion
controls. Complete GPU clocks and verified resident 1/2/4/8 workloads remain priorities.
Thirteen LIVE queries and ten source records are retained; 34 ranked hypotheses
preserve earlier negative results.

[Experiment](experiments/fzc-tail-boundary-20261021/README.md),
[dated report](progress/{run}.md),
[handoff](handoffs/20261021-fzc-tail-fold-pack.md). Saved files do not establish delivery.
''')
(R/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle 0117 COMPLETE: `{run}`. Checkpoint UTC: {now}.
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

Probe/census/audit: {p['wall_seconds']:.6f}/{c['wall_seconds']:.6f}/{a['wall_seconds']:.6f} s;
max RSS {max(p['rss_kib'],c['rss_kib'],a['rss_kib']):,} KiB. Seed 202610210117. One worker,
nice 19, 59s CPU/alarm, 60s parent timeout, 512 MiB AS, <=128 MiB estimated memory.
No native build/GPU/proof. candidate_fold_pack.cuh is UNCOMPILED; handoff:
handoffs/20261021-fzc-tail-fold-pack.md. Main reviews/integrates; no merge here.

13 LIVE queries / ten primary records append 727 -> 737. Current Chimera/CMU/ICICLE/
Efficient Sumcheck refreshed; older 2019 CUDA Graphs source newly screened. Commit
429 and license/PDF failures retained without bypass. 34 hypotheses preserve all 31
prior entries and negatives; top four priorities unchanged. Tested tail is rank 13.

{next_action}

{clocks}

{historical}

D32/D37 and narrow D33/D36 acceptance were read; preserve D30 N-r9-a/b and DD privacy
review. No 8B/GPU/DD/new-fidelity acceptance inferred.

{limits}
''')
(H/'README.md').write_text(f'''# FZC CPU-tail boundary study — cycle 0117

Run `{run}`. Checkpoint: {now}.

{summary}

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

{clocks}

{next_action}

{limits}
''')
# Human-readable handoff; leave complete source/experiment detail in README.
(R/'handoffs/20261021-fzc-tail-fold-pack.md').write_text(f'''# FZC tail fold/pack — owner handoff — 2026-10-21

No proving speedup measured. Run `{run}`; candidate is low priority.
Research patch: `experiments/fzc-tail-boundary-20261021/candidate_fold_pack.cuh`
(UNCOMPILED). See the experiment README for measurements, limits and source pins.

The interface takes immutable dense-strided Fp2 tables, original table count k,
stride, half length, current challenge r and a fresh disjoint k*half output buffer.
It reads MSB pairs i/i+half at t*stride and writes t*half+i, retaining both coordinates.
It omits the derived tables because the host evaluates the original FzcDesc polynomial.
Original tables stay internal; no masks, openings or randomness are reused.

The active seam is `ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/cuda.rs`,
`DevFzcRounds::try_fold` (existing to_host branch, around line 4730), together with
`fzc_kernels.cu` and fzc_module's function-registration lists. Replace boundary
k_sc_fold + k_fzc_pack with fold_pack into the same packed allocation; retain profile
sync discipline, copy/sync, host-table construction and logical-length update.
Preserve module source-key invalidation and every constructor/raw/layout/range gate.
The root currently has a separate GPU implementation; this is not an integrated patch.

At illustrative n21/k21/kd23/half32: remove one launch, 24 KiB logical device traffic
and 64 derived folds. Retain 10.5 KiB copy, pinned allocation, synchronization, host
work and the minimum 736 MiB arena request. Native time and actual VRAM are unknown.
Keep threshold 5; thresholds 8/10 cost 8x/32x copy and introduce Rayon regions.
No numeric end-to-end rate follows; free removal of unknown exclusive fraction f
bounds total speedup by 1/(1-f), while this removes only part.

Synthetic evidence: 859 checks, 48 FZC cases / 160 rounds, 80 boundary cases and nine
controls; independent 55,423-check audit of 6,144 schedules, 11 pins and six controls.
Full Fp2, original table order, MSB pairs and all eleven geometric pad powers retained.
No native masked proof or verifier ran.

Before integration, the owner must test the actual device with k20/21, degree4/5,
threshold0/5/8/10, n1..11 boundary cases, split/fused/raw switches, BASE and extension
inputs, all pad powers, dirty scratch/shrink/grow, fallback and failure paths.
The existing raw gate prevents consuming unmaterialized original rows after round0;
retain it. Compare canonical unmasked rounds, masked messages, next challenges,
terminals, RNG counts, whole receipt bytes and refusals. Independently verify receipts.
Reject on any mismatch, stale/raw read, later derived-table use or enclosing slowdown.
Measure exclusive boundary and full workload with profiling off; profiling adds syncs.
Owner builds/device runs require the shared heavy/build locks. None ran here.

{clocks}

{next_action}

{limits}
''')
print(json.dumps({'readable_reports_finalized':True,'utc':now}))
