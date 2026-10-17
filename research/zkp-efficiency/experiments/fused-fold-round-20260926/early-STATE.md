# ZKP efficiency explorer — durable state

Last completed: **2026-09-26 / cycle-0004**, run `20260926T195233Z-cef0b7d6`.
Started 19:52:33 UTC; final checkpoint UTC is in experiment validation.json.
Outcome: **exact pair-cache arithmetic candidate, small measured phase ceiling;
no measured proving improvement**. Research only, no merge.
No next cycle before **20:52:33 UTC**. Scheduling belongs to the supervisor;
this file does not establish supervisor/process liveness.

## Target and boundaries

This run's explicit target: complete private **8B attention-plus-FFN >=50
proved tokens/s**, existing 512-token prefill **<=10.24 s**, including witness
preparation, per-proof preparation and serialization. Five seconds is a stretch.
Report proving and verification separately. Prefill does not establish decode.
Newer project notes permit larger workloads for amortization; recorded without
changing this run's assigned comparison. No complete private 8B timing exists.
P1 hides inputs/outputs/activations; P3 also hides weights. D22 remains CPU toy
only; D19b/D23 remain proposed. No security/privacy acceptance changed.

Research-directory writes only, excluding runtime/. Production read-only.
One-thread CPU experiments <=60 s and <=512 MiB. No GPU/build/install/Git,
external writes/messages, escalation, production/reviewer edits or queued jobs.
Main/Claude reviews and integrates handoffs.

## Latest result and evidence

- [Experiment](experiments/pair-inverse-cache-20260926/README.md),
  [result](experiments/pair-inverse-cache-20260926/result.json),
  [validation](experiments/pair-inverse-cache-20260926/validation.json).
- **76 differential cases, 21,015 independent coefficient solves, 41 helper
  schedule/refusal models, 11 negative controls pass.** One CPU, 0.2075 s,
  26,292 KiB RSS, seed 2026092604. No native proof or GPU executed.
- [Handoff](handoffs/20260926-pair-inverse-cache.md): two Rust helper functions,
  70-line **unapplied/uncompiled** patch for the shaped candidate at
  `/tmp/zk60-groups-20260926/hashline/src/private_block/protocol.rs:908`.
  Source hashes/excerpts retained; original full public-table loop unchanged.
- Valid 16,384-word helper, 256 public pairs: **49,152 -> 768** counted batch
  multiplications, one inversion either way. Output/H commitment unchanged.
  Small-column cache setup loses; invalid-heavy scalar fallback adds inversions.
- Cache hits require BOTH index and value. Invalid pairs keep old arithmetic;
  unused zeros still refuse at the original later whole-table stage. Phase
  ordering is modeled, not established in a native transcript.
- [Latest bottlenecks](experiments/pair-inverse-cache-20260926/bottleneck.json):
  R2a non-warm candidate helper 0.217/0.232 s, **0.54–0.58% of proving**;
  removing the entire phase saves <0.5% of known witness+prove+serialization
  sum. Shared two-thread synthetic 125M CPU, compilation
  overlap; no GPU/8B projection. Grouped A/B still waiting for heavy lock.
- Five primary-source records appended to sources.jsonl. LIVE search found
  fractional GKR and Plonky3's merged multilinear lookup implementation;
  bind/measure fusion appears in release notes. No upstream speed reproduced.

## Preserved prior work

All four cycles and negatives remain in FINDINGS.md and sources.jsonl.
Prior [NTT/pad handoff](handoffs/20260926-ntt-layout-and-pad-overlap.md):
source-derived CUDA q>n overlap repair still untested on device; mapped layout
does not remove a restore copy from current code, which has none.
Earlier [grouped sumcheck handoff](handoffs/20260924-sc-szc-groups.md) remains;
native grouped correctness passed in the owner's lane, timing pending.
Separate-session budget, amortization and KV handoffs remain unchanged.
Their synthetic/counting evidence is not a private-model proof measurement.

## Next concrete experiment and rotation

**Memory traffic: fuse fold and next-round accumulation** at the inspected
`zkp-core/src/sumcheck/rounds.rs` / `grouped.rs`, preserving
`SumcheckRounds::{round,fold,finals}` and MSB variable order. Four old quarters
form the two next-round endpoints after challenge r; read each once, write
the folded table, accumulate the next polynomial samples while values are live.
Start with four synthetic tables and degrees 2/3, compare to separate passes
and an independent direct-MLE oracle. Cover final fold n=2, empty next-round
state, awkward chunk boundaries, extension r, zero equality factors, wrong
quarter/order controls. Count memory reads/writes/scratch, not predicted speed.
Then assess SC_SZC group integration if the basic exact oracle passes.

Remaining rotation: batching/amortization -> quantization/arithmetic -> proof
composition -> sumcheck/GKR -> GPU NTT/commitments -> lookup/softmax.
Fractional-GKR helper-column removal is a high-cost protocol research lead,
requiring new masked-channel/PCS/lookup-link analysis; not an approved rewrite.

## Access qualifications and resume

Plonky3 release shows Sep 23 without verified year; exact date null. Full
commit IDs from hyperlinks, commit contents unavailable. Main MIT text read,
version-specific license unavailable. docs.rs/latest served 0.7.0 despite
newer release notes. Cache misses/Internal Errors and GKR PDF robots denial
recorded; no bypass. No permission approval was requested or needed.

Resume by reading this state, FINDINGS, sources and latest results, then
project CLAUDE.md, MVP_STATUS, decisions and active coordination. Preserve
negative results and do not copy real private model material into artifacts.
