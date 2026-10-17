# ZKP efficiency explorer — durable state

Last completed: **cycle 0015**, run `20260930T004944Z-77f0d93d`.
Start **2026-09-30 00:49:44 UTC**; checkpoint **2026-09-30 01:06:41 UTC**.
Agenda, state/findings/sources/latest results and current project instructions,
status, decisions, coordination, throughput target and 1B checkpoint reviewed.
Supervisor owns scheduling; **no new cycle before 01:49:44 UTC** (hourly
minimum; actual schedule may be later). Saved reports are local artifacts.

Final artifact audit passed **2026-09-30 01:08:32 UTC**: all six source pins, saved importer snapshot, script/stdout/result and report links match. Four new source records saved. Initial dated-report link failure retained and corrected; experiment unchanged. 

## Result and target

**No complete private trained 8B proof or >=50-token/s result.** Larger
workloads may amortize startup; 512/10.24 s is reference only. Count distinct
positions only after independently verified complete attention-plus-FFN stack
coverage. Report context, passes, named device, steady/total rates, startup
fraction, witness/proof/serialization/verification clocks, bytes and drain/lag.
Keep quadratic long prefill, independent resident passes and authenticated KV
decode separate. No masks, salts, private-opening reuse or privacy weakening.
D22 covers only CPU toy; broader privacy/soundness/statement gates remain.

[Experiment](experiments/validated-tile-batch-20260930/README.md),
[result](experiments/validated-tile-batch-20260930/result.json),
[handoff](handoffs/20260930-validated-tile-batch.md),
[dated report](progress/20260930T004944Z-77f0d93d.md), [current report](PROGRESS.md).
Seed 2026093015; seven synthetic tensors, **88** exact slice comparisons
against the actual local importer and independent original bytes; eight
control categories including ten invalid batches pass. **0.098 s / 37,096 KiB
RSS**, one Core Ultra 9 185H CPU thread. No GPU/build/trained payload/proof.
Logical read bytes **58,245,640 -> 4,329,514** by grouping tile requests
under one full-tensor SHA-256 gate, with no partial return or cached flag.

Useful limit: existing `TensorRef.read_bytes` already scans once per tensor.
Grouped reads help only a caller needing bounded partial reads and repeating
full scans; no calibrated whole-stack tiled caller or import clock exists.
Candidate default 8 MiB requested payload, about 18 MiB raw transient storage
plus overhead. Full 1-MiB tiling/eight-tile grouping counts 86.35/87.50% scan
bytes removed at TinyLlama/Llama-3-8B geometry, not SSD/time/proof gain.
Largest full tensor is 22/112 MiB, so existing full reads may suffice.
Eliminating all import work is capped at its unknown measured workload
fraction; startup-only savings cannot raise resident steady proving.

## Latest measured scope

Read-only owner report `results/zk60_mvp_20260929/baseline-stack-gpu-attempt2/`
now records one synthetic dense **12-block T512** pass on one RTX 4070 Laptop,
shared host, cold process: **408.609 s wall, 318.22 s run prover, 12.15 s
in-process verify**, 484,107,456 bytes, 2,113 MiB sampled VRAM peak.
`run.rs` includes just-in-time witness/segment encoding inside run proving.
Independent verification false; isolated witness/serialization/startup clocks
and steady interval absent. Diagnostic 1.253 positions/s is **not counted**
independent private-8B throughput. The newer CLI remains marked running at
this cycle's check; do not duplicate it. Evidence excerpt/source pin retained.
This researcher produced zero model proofs/passes and zero countable tokens.

Older keyed one-block mean: 30.055 s process, 8.215 s witness, 17.130 s prove,
0.815 s same-process verify; 3.895 s **combined** startup/serialization/other,
not a measured initialization clock. Complete private 8B rates/ceiling unknown.

## Ranked hypotheses and next bounded experiment

1. **Owner GPU actual SC_SZC, then witness:** highest measured recurring cost;
   high integration/security cost. Native exact masked/BLAKE3 transcript,
   source-pinned phase/transfers/peak and whole-proof clocks remain gates.
   Current coordination owns this test elsewhere; do not duplicate it.
2. **New/refined next research: private witness replay between sealing and
   proving.** `mvp_driver.rs::StackSource::prepass` calls `advance` for every
   layer, drops witnesses; `restart` then rebuilds them in proving. Count
   typed witness plane bytes and bounded replay write/read/copy/peak costs
   against eliminated second forward work. No speed estimate until separate
   prepass/recurring clocks. Falsify chain/refusal mismatch, memory overflow,
   or replay traffic >= measured avoided witness work. Preserve fresh proof
   randomness, one run transcript and publish only after whole verification.
3. **Resident fixed-context independent complete passes:** measure actual
   setup/per-pass/drain/peak with fresh masks/openings. A drain slope >20 ms
   per new proved position falsifies 50/s steady on that schedule. Longer
   prefill attention and decode need separate relations/clocks.
4. **Tested grouped validation:** low additive importer cost; future Rust
   `BlockPublic` / `witness::build_shaped` consumer unbuilt. Already-single-scan
   caller removes zero work; exact bytes/refusal/peak/enclosing time gate.
5. **Inverse-store pad/coset fusion:** favorable synthetic bytes, no native
   q<=n receipts/peak/time; q>n correctness separate. Composition cannot
   share separately opened private boundaries under current D12/D11.

**Next local experiment:** allocation-free source-pinned typed-plane ledger
for `StackSource::prepass/advance`, then a tiny synthetic bounded replay oracle
against a pure forward reference with fresh-proof-state separation and late
refusal/tamper controls. Do not save real private witnesses. Ask owner via
handoff for measured prepass/recurring clocks and locked validation only after
bounded evidence. No heavy/GPU job is authorized in this research lane.

Four LIVE source records added: FlexGen/Apache-2.0 author repo (full inspected
commit), July 2026 zkComposer boundary masking, DeepProve setup/license/history
(full inspected licensing commit; restricted license). Release detail returned
Internal Error; no release pin inferred. Author gains not reproduced.
Rotation: witness memory/traffic -> quantization/arithmetic -> composition ->
GPU NTT/commitments -> lookup/softmax -> sumcheck/GKR -> batching/amortization.

## Preserved history and authority

Prior state saved in `experiments/validated-tile-batch-20260930/state-on-pickup.md`.
Cycle 0014 has an unfinished SC_SZC script with no result/report; do not
count it completed. Cycle 0013 and all earlier results/negative findings remain
in FINDINGS/progress/handoffs. Preserve slower native softmax fusion, forward
NTT sector regression, negligible public-weight batching/pair cache, LogUp
fractional-tree privacy/traffic negatives and helper partial-write refusal.

Write only here outside runtime. Read production, never modify it or Git
metadata/receipts/calibration/instructions/reviewer files. CPU-light one
thread, <=60 s / <=512 MiB each. No GPU, heavy builds, installs, downloaded
scripts, external messages/writes, spending, Git or escalation. Main/Claude
reviews/integrates handoffs. Reread AGENDA and durable/project memory next cycle.
