# Active cycle checkpoint — 2026-09-30

Run `20260930T004944Z-77f0d93d`, cycle 0015. Start 00:49:44 UTC; finish by 01:09:44 UTC. Agenda and durable memory reread. Previous cycle 0014 left only an incomplete actual-SC_SZC script and no result; do not count it completed. Current coordination assigns the native actual-SC_SZC transcript boundary to an owner lane, so this cycle will test complementary resident/pass scheduling or memory cost after newer evidence review. No production edit, GPU, build, installation or Git action. Full private 8B >=50 target unchanged. Prior state retained below; checkpoint pending.

# ZKP efficiency explorer — durable state

Cycle 0014 started 2026-09-27 05:52:33 UTC, run `20260927T055233Z-5d1eb3b0`.
Agenda, durable state, findings, sources, latest experiment, target and project
status reviewed. Current work: exact SC_SZC lookup/helper differential at the
CPU seam, followed by checkpoint and dated report. No production edit or GPU
job is authorized in this lane.

Last completed: **cycle 0013**, run `20260927T045233Z-e6183046`, started
2026-09-27 04:52:33 UTC. Do not start another cycle before **2026-09-27
05:52:33 UTC**; supervisor owns scheduling. Reports are local files, not
proof of user-message delivery. No complete private 8B result.

## Current result and next action — cycle 0013

[Experiment](experiments/sc-szc-device-round-20260927/README.md),
[result](experiments/sc-szc-device-round-20260927/result.json),
[handoff](handoffs/20260927-sc-szc-device-round.md),
[dated report](progress/20260927T045233Z-e6183046.md). Seed 2026092713;
four synthetic SC_SZC-shaped profiles, 110 independently reconstructed
original-cube round samples, 91 direct finals and eight mutation controls
pass in 0.510 s/17,140 KiB RSS on one Intel Core Ultra 9 185H CPU thread.
Two tile sizes at 128 rows/26 tables yield the same masked-message digest.
Actual slot lookup/helper polynomial, BLAKE3 transcript, native receipt,
GPU speed and full-model throughput were **not** tested.

Leading question refined: can a device-resident SC_SZC round route retain
exact host CFS masking/Fiat–Shamir and still beat CPU after each dependent
message/challenge exchange? Current generic CPU baseline scans/folds all
tables. The candidate moves that work to device but removes **no** table
reads/arithmetic and adds upload, final transfer, 2–3 launches/round,
host-device synchronization, VRAM and integration/security review. At
synthetic N=128/k=26/d=4 the source-counted round/fold table reads are
211,328 B and writes 52,832 B in both schedules; upload 53,248 B;
reduced messages/challenges 672 B and seven sequential dependencies.
Logical counts are not runtime. The old GPU-assisted 125M one-block mean
30.055 s wall and 17.130 s proving, with softmax roughly half proving;
deleting that **entire** approximate 8.565 s slot at zero cost would
still leave ~21.49 s for that one block. This schedule can remove less.
For 8B the end-to-end ceiling is unknown. Falsify on exact native
masked/transcript/receipt or refusal mismatch, VRAM overflow, or no
quiesced enclosing proof gain.

Ranked hypotheses: (1) GPU attention SC_SZC with measured transcript
boundary; high impact potential but high integration cost, exactness and
privacy obligations. A later on-device keyed BLAKE3/mask route could
remove exchanges only after separate review. (2) Fixed-context resident
complete passes; measure registered 8B setup/pass/drain/memory first;
>20 ms complete-proof drain per new position falsifies 50/s steady on that
schedule. Keep long prefill T-squared attention and decode/KV binding
separate. (3) Inverse NTT final-store fusion; favorable synthetic bytes,
but native q<=n receipt/peak/time parity and q>n correctness repair
remain. (4) Incremental KV/proof-window and preprocessing only with
authenticated state and fresh private openings. Previous slower native
softmax fusion and NTT forward-load sector regression remain negatives.

Six native LIVE primary-source records added: 2026 equality/streaming
sumcheck, DATE 2026 SumCATS paper/author repository, zorch device-FS
issue, NVIDIA July 2026 binary-field RTX 5090 report and older 2024
time-space work. Their reported kernel speedups are author claims for
different fields, not reproduced 8B evidence. Exact URLs/dates/licenses/
commit limits in `sources.jsonl`; no external code executed.

**Next bounded local experiment:** pin the **actual** SC_SZC lookup/helper
closure and CFS/BLAKE3 transcript in a CPU-only differential, including
ragged grouped tables, exact masked round bytes, challenge/final/extension
order and controls. Then seek owner locked per-slot GPU clocks only after
parity and memory accounting. Rotation after that: resident-model pass
amortization, arithmetic/proof composition, GPU NTT. Reread AGENDA,
STATE, FINDINGS, sources, latest results and project docs on pickup.

## Prior cycle 0012 checkpoint (archived)

Prior completed: **cycle 0012**, run `20260927T035233Z-8a5c6f18`, started
2026-09-27 03:52:33 UTC; final artifact audit and checkpoint **04:07:56 UTC**.
Experiment, primary search, handoff, FINDINGS and progress reports are saved.
Its next-start time was 2026-09-27 04:52:33 UTC. These reports are local files,
not proof of chat delivery.

## Target and authority

>=50 independently verified complete private 8B attention-plus-FFN proved
tokens/s on one RTX 5090 or named high-end GPU. Larger workloads may amortize
initialization/prefill; 512/10.24 s is reference only. Count every full-stack
position once and report context, passes, steady/total rates, startup fraction,
witness/prove/serialization/verification clocks, bytes, proof lag and device.
Long prefill has T-squared dense attention; fixed-context independent passes
are aggregate throughput; decode needs authenticated growing KV state. No
mask, salt or private-opening reuse or privacy weakening is authorized.
D22 covers only the CPU toy privacy profile. D19b/D23 and larger-profile
privacy/soundness acceptance remain pending. **No complete private 8B result.**

Write only under this research directory outside runtime. Read production,
never modify it or Git metadata. One CPU thread, <=60 s and <=512 MiB per
experiment. No GPU jobs, heavy builds, installs, downloaded scripts, Git,
external writes/messages or escalation. Main/Claude integrates handoffs.

## Prior cycle's exact result and limits

[Experiment](experiments/inverse-store-pad-20260927/README.md),
[result](experiments/inverse-store-pad-20260927/result.json),
[handoff](handoffs/20260927-inverse-store-pad.md),
[dated report](progress/20260927T035233Z-8a5c6f18.md). Seed 2026092712;
56 synthetic cases, 16 ragged multirow chunk comparisons, 816 independent
DFT/polynomial points and eight controls pass in 1.394 s/29,704 KiB RSS,
one thread, Intel Core Ultra 9 185H. Source and script SHA-256 in result.
No native/GPU compilation, receipt or complete proof.

Baseline compact chunked hiding encode: inverse NTT final store into `coef`,
separate `k_zk_pad_scale` into `coef2` at pw=n+q, forward `k_ntt_p1`.
Candidate writes normalized pad/coset output into already allocated `coef2`
at the inverse final store and assigns each inverse tile a disjoint tail.
At n=16384,q=256,nn=65536 it removes 262,144 logical bytes per row from
this isolated interface and modeled 32-byte sector requests 20,736 -> 12,544.
Large-n two-buffer scratch peak is unchanged; q-tail work, registers,
occupancy and actual GPU runtime are unmeasured. For n<=4096 `coef` could
be freed after a caller lifetime change. Current CUDA q>n branch omits a
negative overlapping pad term relative to the CPU polynomial; treat as a
separate correctness repair, not parity with the old GPU. Alias of n-wide
`coef` to pw-stride output across rows is unsafe. The earlier first-forward-
load fusion's 9.55% large-row sector increase remains a negative finding.

## Prior owner measurement and ranking

The main team's keyed RTX 4070 Laptop (8,188 MiB) A/B finished while this
cycle ran. One synthetic dense 125M T512 block; two non-warm samples per arm,
fresh process/device initialization, shared two-thread host. CPU/GPU mean
whole process 39.895/30.055 s; witness 5.845/8.215 s; prove 32.950/17.130 s;
verify .905/.815 s; serialization+other/startup residual .195/3.895 s.
All six 40,783,352-byte receipts verify. GPU mean host RSS 4,411.5 MiB,
VRAM peak not measured. One GPU witness sample 10.66 vs 5.77 s; this
researcher was active, so timings are not quiesced. Separate startup and
serialization clocks, steady interval and proof lag absent. **Zero full-model
passes and zero countable proved tokens**; no 5090 or trained 8B timing.
Owner coordination estimates softmax about half of remaining GPU proving.
The prior proposed native softmax fusion was 1.66% slower in CPU proving,
so do not repeat/promote that exact sketch.

1. **GPU masked softmax/sumcheck:** top measured recurring proving cost.
   Refined question: can grouped SC_SZC round generation/fold be tiled with
   exact masked/challenge polynomial while avoiding repeated host-device
   traffic? The `SC_SZC` attention slot currently uses the generic CPU
   `hashline/src/zk.rs::masked_prove` -> `zkp-core/src/sumcheck.rs::prove`;
   existing `k_sc_round_zc*` CUDA kernels serve FFN zero checks and are not
   this slot's route. A new device route has **high integration cost**;
   eliminated work must be named by source-derived ledger. Added costs are
   transfers, synchronization, register/shared-memory pressure and any
   extra masked arithmetic. Complete-proof ceiling unknown until native
   phase attribution. Falsify by polynomial/transcript mismatch or no
   enclosing readiness gain. Do not alter refusal or fresh randomness.
2. **Fixed-context resident-model pass amortization:** potentially high
   impact, but needs registered 8B layout, measured setup/per-pass complete
   clocks, memory and drain. A full-proof drain slope >20 ms per newly
   proved position or memory overflow falsifies >=50 on that schedule.
   Keep long prefill and decode separate; no private opening reuse.
3. **Inverse-final-store fusion:** exact synthetic and favorable source-address
   ledger, moderate native integration; no GPU phase clock/peak yet.
   Promote only after q<=n byte-identical keyed leaves/openings/receipts,
   then phase and full-proof A/B with no peak regression. q>n separately.
4. **Direct H U8 writer:** prior exact synthetic but even deleting the entire
   helper phase caps old CPU one-block readiness at 2.87–3.04%. Keep its
   guarded no-partial-private-H refusal rule.

Other retained negatives: fractional-GKR root disclosure/tree traffic;
public-weight batching <0.1%; pair-inverse-cache small ceiling; original
NTT load-fusion sector regression; slower native softmax fusion. Prior
findings and handoffs remain in FINDINGS.md, PROGRESS history and `handoffs/`.
The chunked GPU PCS route already avoids retaining full A/H codewords;
source-derived host H construction still has a 9.86-GiB floor at unregistered
T512 Mistral geometry. Do not reclassify materialized-host floors as GPU-path
facts.

## Prior sources and next action

Four native LIVE primary records this cycle: NVIDIA cuPQC 0.6.0 NTT
features/guide plus SDK terms and Apache-2.0 sample repo (date/commit
unavailable; custom-prime `<2^62` excludes Goldilocks); ePrint GPU NTT
paper received 2023-09-19/revised 2023-10-06; arXiv NTT/sumcheck study
v1 2026-06-15. External timings are author claims, not reproduced.
Exact URLs, access date, license and commit limitations in `sources.jsonl`.
No external code copied or executed.

**Next bounded local experiment:** a one-thread exact masked SC_SZC round-tile
and fold schedule oracle at `hashline/src/private_attention/argument.rs::SC_SZC`,
`hashline/src/zk.rs::masked_prove` and `zkp-core/src/sumcheck.rs::prove`,
measuring logical table
reads/writes and checking direct polynomial samples, extension limbs,
challenge order, mask schedule, zero factors, ragged table groups and negative
controls. The current FFN CUDA kernels are only interface examples, not
an existing SC_SZC device implementation. Avoid repeating the slower
completed fusion sketch.
Then seek owner native phase A/B under locks; revisit fixed-context resident
amortization when registered 8B setup/per-pass clocks exist. Rotation after
softmax: batching/amortization, arithmetic, proof composition, GPU NTT.

At next pickup reread AGENDA, STATE, FINDINGS, sources, latest results,
CLAUDE, MVP_STATUS, ZK60_DECISIONS, active coordination and target. Refresh
PROGRESS and dated progress report after one bounded cycle.
