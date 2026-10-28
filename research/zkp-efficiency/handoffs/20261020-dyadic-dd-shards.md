# Research handoff: public DD union, promising counts with unresolved native binding

Run `20261020T221854Z-d390b45f`; cycle0114, 2026-10-20 UTC.
**No native patch, proof, profile admission or measured speedup.**

At S12/f_e9/F_P12/head_dim128/base e_s2, a public156-value dictionary can
use domains128+32 instead of cap256. At counted8B T512 this changes
803,176,448 ->766,607,360 A+H committed words (-4.553058% versus single DD,
-8.337578% versus direct HIGH), including one extra complete set of claim
masks. Selected dictionary payload768->480MiB is partial accounting only.
At T128 the same choice remains4.928441% larger than direct division.

The exact156-slot partition128+16+8+4 loses to128+32 because it needs two more
fresh mask sets. Splitting248 outputs loses to single cap256 at both contexts.
Small shards must satisfy native no-lift: capacity>=4 atT128 or>=2 atT512.
These findings disprove simple cardinality-only scheduling.

Research implementation and interface:

- `experiments/dyadic-dd-shards-20261020/probe.py`: `best_caps(n,minimum,data_cost,mask_cost)`
  returns a public minimum-word partition; `count(T,caps)` charges data,
  independent fresh A/H masks, slots, CFS/M rows and PCS groups.
- `shard_column(sorted_public_support,caps)` partitions the full public support
  and pads with valid zero entries; `digest` is only a research binding oracle.
- Synthetic score tuples share one query helper over the union of shard tables.
  Each shard has separate A multiplicities and H table helper; all table
  helpers have sign-1 in the one original value0 sum. No private routing witness
  or separate published shard sum is used.
- `audit.py` imports no producer/vendor code. It checks90-digit public tables,
  exact rational tuple identities, all division cells, independent partition
  enumeration and literal source-backed mask/wire counts.

Native review seams, pinned to frozen R9 in `source-pins.json`:

- `hashline/src/private_block/shape.rs`: Dd domain family, geometry,
  `claim_sites`, slot count, PCS groups and `receipt_bytes`.
- `layout.rs`: dynamic plane IDs/HIds, table-helper classification, independent
  reserved mask/opening sites and one value-zero sum.
- `argument.rs`: one SC_DD instance per shard, correct public E subcolumn,
  A_SUM slice on leading(h,t) variables, all-slot exact division and helpers.
- `witness.rs`/`protocol.rs`: deterministic first-occurrence histograms,
  every denominator inverted even at multiplicity0, A before beta/gamma/alpha,
  shared score tuple helper and every table-side negative sign.
- E-column loading and trained/run statement schema: bind public table,
  partition/cap order, domain/slot order and per-layer schedule before challenges.
  Existing calibration API refuses these plane-list changes.

The interface needs a new reviewed profile and native implementation. Do not
edit admitted R9 profiles or inherit their privacy acceptance. Preserve
D30 N-r9-a (row-Sum, slot17, Ht relation) and N-r9-b (M_dd in A before lookup
challenges), full original attention/FFN coverage and fresh per-proof masks.
Every added Sum read needs its own reserved site. Count/review whole-run
soundness, refusal distance, rank/NL-1/joint-view privacy, challenge order,
field no-wrap and degree/group assumptions. The current byte counts exclude
new schema metadata. No copied public source was executed.

Validation:53,680 producer checks/60synthetic rows/19,200query positions/
16controls; independent8,128checks/20,480public entries/3,360positions/
13source pins PASS. Probe0.146128s/17,640KiB; audit0.035228s/18,480KiB.
OneCPU worker,59sCPU/alarm,60sparent,512MiBAS,64MiBestimate; Intel CoreUltra9
185H/WSL2; no GPU. Initial duplicate-zero mutation-control failure retained.
Commands, seeds, dimensions, final source hashes and limitations are in the
experiment directory.

Promote only after actual HIGH tables/D32 fidelity arrive and independent
native relation/privacy gates pass. Then measure complete exclusive/enclosing
phase clocks and capacity under owner locks. The affected exclusive fraction
is unknown: even free deletion has ceiling1/(1-f), before new costs. Neither
layout counts nor source claims establish >=50 proved tokens/s.

New full-stack proofs/passes/positions0/0/0; no model context, GPU, prefill,
resident pass or decode. Witness/proof/serialization/verification clocks,
startup fraction and both workload rates remain unmeasured. Main/Claude owns
review/integration; no merge or external message was performed.
