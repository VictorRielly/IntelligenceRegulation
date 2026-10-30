# R13 looked-column alias storage — reviewable interface, no native patch

Cycle0139 `20261029T085649Z-193029f7`. 2026-10-29T09:12:05.812753+00:00. Main/Claude reviews and integrates; no merge here.

Candidate `experiments/lookup-public-incidence-20261029/candidate.py` is a
synthetic interface model. There is no compiled/applied Rust patch.
Pinned seam: frozen R13 `hashline/src/private_block/protocol.rs`:
`lookup_values_at` (line394), `byte_histogram_at`, `u8_misses_of`, helper loop
(line1159) and `drop(looked)` (line1228). `accuracy_layout.rs::lookups` (line109)
emits original descriptor order; `argument.rs::lk_tables/helper_sum` remains
the original relation. Twelve source hashes in the experiment manifest.

Proposed Rust container, scoped to one domain and one proof invocation:
`LookupColumns { unique: Vec<Vec<i64>>, order: Vec<usize>, multiplicities: Vec<usize> }`.
`column(logical_index)->&[i64]` resolves the original position through `order`.
Plan construction keys the complete public `Lk` expression plus domain; source
ids are SHAPED ids. Do not key only source, length, coefficient or private values.
Keep every logical occurrence, including full-byte identity pins. Callers keep
the original lookup_words, public threshold branches, helper count/order and
table helper construction. Weighted histogram/miss scans use public checked
multiplicities; keep bin0 handling of invalid words. Maintain wrapping i64
arithmetic exactly. Release private buffers at the original lifetime; prepare
new private vectors for every proof/witness. No cross-proof private cache.

Model 11,874checks/1,872fixtures/104helper cases
and14controls pass; separate audit 237checks/4source mutations/12pins.
Logical data match includes arbitrary signed endpoints, overflow, alias multiplicity,
new private sources, helper grouping, equal-pair poles and out-of-table fallback
poles. Native full table poles/refusal order, constructors, RNG draw order,
transcripts, PCS, receipts and privacy are unexecuted and remain acceptance gates.

Representative source-derived8B T128 fE9 looked490.25->481.25MiB noDD,
463.25->460.25MiB DD; fE12/16 saves1MiB each. Counts match the owner's public
census, not actual per-layer calibration. v16 yields one Kv alias; wrho16
yields two S or Dd aliases. pv16 can add one Q alias; sensitivity is labelled
separately. No modeled A/H/M/helper/mask/PCS reduction. Actual peak, source
traffic and enclosing time unknown; metadata and indexing cost are added.
Do not represent these counts as a native proof-byte or memory measurement.

First owner measurement: actual admitted layer precision descriptor incidence
and exclusive lookup generation/histogram/miss/helper/enclosing clocks, plus
overlap/peak owners. Only if useful, implement original vs container A/B under
current shared locks. Preserve old path as oracle and run golden/refusal,
RNG/transcript/PCS/privacy and independent complete-workload verification.
Any mismatch or enclosing regression falsifies promotion. With removable f
unknown there is no numeric end-to-end ceiling; even free deletion is1/(1-f).
Whole-prover GPU/resident1/2/4/8 and admitted context scaling retain priority.

No new complete proof or positions counted. Target unchanged/unachieved.
