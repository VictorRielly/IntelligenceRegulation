# Conditional full-loader SHA identity reuse — owner review only

Cycle0132, `20261029T015649Z-e607e256`, 2026-10-29 UTC.

No native gain measured. The synthetic exact-byte prerequisite passes
5,150 checks and2,584 control instances. At the inspected untied8B geometry,
six identity weight arrays and exp/act can share their full-load checked raw
SHA with LayerRecord, avoiding1,342,521,344 logical hash input bytes per
32-layer scan. Three64MiB FFN tasks remain; a parallel scheduling countermodel
shows zero wordSHA makespan gain at2/4/8/16 workers. Do not infer elapsed gain.

Interface and patch location: internal full branch of
`TrainedExport::load_layer_mode` in trained_block.rs, feeding a private
same-construction LayerRecord helper beside trained_statement.rs::of_block.
The design is in
`experiments/layer-stream-digest-20261029/candidate-interface.rs.txt`;
it is uncompiled/unapplied. No production patch is supplied or integrated.
Keep generic of_block, actual block BLAKE3, all source checks and all
metadata/shape/support/CS/H-1/DD gates. Constrain provenance to the same
verified loaded bytes and block; never accept caller/imported hash authority.

Native reload already creates unhashed records and compares the actual
rebuilt block digest in BlockCache and ExportTokenBlocks. Its raw reader's
check_sha=false assigns want without authentication; it never qualifies as
a checked raw digest. This candidate saves zero reload SHA work. No new
reload hashes, public snapshot API, cross-request cache or mask reuse.

Validation: independent destination-indexed signed serialization covers
32 small geometries/data fixtures and all13 arrays, raw/rehashed mutations,
padding/head permutations, endian/signed stress, layer/manifest/order/profile
binding and unverified reload controls. Exact native canonical preimage
bytes match the model. SHA256 is an explicit block-digest surrogate;
native BLAKE3, registered generators, full refusal order, RNG/transcripts,
PCS, Rust module authority, concurrency and native receipts are not tested.
Record/source metadata outside the selected hash fields is not modeled.

First owner action: measure exclusive raw read/SHA, pad/constructor,
recordSHA, block BLAKE3 and enclosing workload clocks at the actual source
revision and thread count. Instrumentation must not leak private data.
If recordSHA is material, review internal ownership and run native full/reload
record/manifest/first-refusal equivalence, frozen golden/RNG/transcript and
independently verified full-stack receipt gates, applicable privacy review,
then resident1/2/4/8 workloads with phase/capacity clocks under shared locks.
No heavy job is queued. Never replace these with the CPU checking duration.

Falsify on any byte/hash/refusal/identity mismatch, trust of manifest want,
native gate failure, zero enclosing improvement or added memory/critical-path
cost. Proof privacy and full-stack coverage are unchanged obligations.
P1 public material only; no P3 weight preprocessing authority is implied.
The >=50 proved tokens/s private8B GPU target remains unachieved.
