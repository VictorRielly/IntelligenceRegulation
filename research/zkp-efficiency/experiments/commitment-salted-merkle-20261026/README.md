# Salted Merkle first-level fusion — CPU model and cost census

Cycle 0125 — 20261026T172925Z-dd337876 — 2026-10-26T17:41:18.145236+00:00

No proving speedup measured. The synthetic CPU model fuses salted-leaf construction
with the first Merkle parent level while retaining every salted leaf and every
internal node. It matches the installed independent BLAKE3 implementation in
**19,952 checks, 120 cases, all 3,825 paths and 17 control types**.
Both the model and the separate reference-tree/path code were authored by this
researcher; the cryptographic implementation is independently implemented installed
Python blake3 1.0.9. The separate interval/cost/source audit passes **16,733
checks**, twelve explicit tree sizes up to2048 leaves, 12 source pins and five
accounting controls. Model 1.197346s / 16,240KiB RSS; audit 0.025621s / 16,164KiB RSS. These are diagnostic clocks, not proof clocks.
Every leaf command uses one-core affinity, nice 19,30 s CPU/alarm,35 s parent timeout,
256 MiB address-space limit and64 MiB estimated experiment memory.

For N encoded columns, baseline salting costs N BLAKE3 compressions and the external
binary tree N-1. These are **ordinary64-byte BLAKE3 messages**, flags CHUNK_START|
CHUNK_END|ROOT, plus KEYED_HASH under a tagged role; using BLAKE3's internal PARENT
mode is wrong and is caught. Native COLUMN, LEAF and NODE keys remain distinct;
fresh salts, their RNG draw order and all pads/masks stay unchanged. There is no
cross-proof private reuse. Fresh synthetic salts change the root as expected.

For N>=2, fusion removes exactly32N logical bytes of leaf reloads and one parallel
pass boundary. It removes **zero compressions, zero stored tree bytes and zero
required path entries**. The stored tree is32*(2N-1) bytes. Logical host salt+tree
reads/writes change from192N-96 to160N-96 bytes, before library/compiler/task costs;
these are source-level counts, not DRAM or cache measurements. N=1 has no saving.

| FrozenR9 one A or H commitment | Encoded columns | Logical reads avoided | Retained tree |
|---|---:|---:|---:|
|T128 nonDD/DD|65,536|2 MiB|4 MiB-32B|
|T512 nonDD/DD|131,072|4 MiB|8 MiB-32B|

Only A/H geometry is counted, not M/endpoints/token stages or the LOW/HIGH fidelity
profiles. T512 is not an admitted trained profile. Per-column BLAKE3 compression
count is ceil(rows/8)+ceil(rows/128)-1; salted leaves+external nodes are only
0.136%–0.457% of total hash compressions across these eight geometries. CPU/GPU
placement differs, so this ratio is **not an elapsed-time fraction**.

Two useful negative findings constrain integration. First, naive safe zero-filled
salted and first-parent buffers add48N logical writes, more than the32N reloads
avoided. The uncompiled Rust candidate instead uses indexed Rayon
unzip_into_vecs and Vec::into_flattened (stable1.80) to fill two outputs and reuse
the pair allocation. Current local Rayon1.12 and standard-library sources were
inspected and pinned. Compiler codegen, task width (three hashes per pair),
register/cache pressure and actual capacities remain unmeasured. Second, moving
salting+the entire tree to GPU while keeping today's host tree.path contract
downloads32*(2N-1) tree bytes and uploads32N salt bytes, versus today's32N digest
download. This adds64N-32 combined transfer bytes:4 MiB-32B atT128 or8 MiB-32B
atT512 per commitment. This comparison assumes all current host tree levels are
returned; device-resident path gathering would be a separate API/lifetime design.
A root-only frontier cannot replace retained levels without charged regeneration
or retained-device paths after transcript queries. No root-only speed claim.

Integration seam: active ops/zkp-mvp/gpu-zerocheck/zkp-core/src/pcs.rs::
commit_zk_owned_with_tag -> MerkleTree::build_salted_keyed in merkle.rs. The
source-pinned salt-first-parent.patch adds the helper and replaces one tagged
commit callsite, leaving existing entrypoint bodies intact. It is **unapplied and
uncompiled**. The existing backend still returns its unsalted Vec<Digest>; no GPU
hook changes. Internal helper shape checks apply to generated valid arrays only;
native failure/refusal equivalence, RNG, all roots/paths, complete receipt bytes,
fresh independent verification, current privacy gates and owner review remain owed.

End-to-end ceiling: if f is the unknown truly removable critical-path fraction,
even free deletion is bounded by1/(1-f), before added costs. No numerical complete
GPU speed forecast follows. Falsify on any digest/node/path/key/flag/order/RNG/
receipt/refusal/privacy mismatch, implicit clears/copies/reloads erasing savings,
absent native incidence, or a slower enclosing independently verified workload.
All37 previous ranked hypotheses are retained;36/37 refined and38 added. The
whole-prover GPU, resident1/2/4/8,DD-context and exclusive-FZC owner priorities stay
above this bounded continuation. Hash micro-optimizations are parked for clocks.

Ten LIVE search queries and primary open/find/click inspection yielded eight
source records (including partial/inaccessible leads). The newly assessed older
merklize-blake3 README separates kernel and transfer costs and requires>=2^20
leaves; GitHub verifies its2023-01-13 archive date, while publication/update/commit
and license-body/code inspection are unavailable (cache misses). cuPQC's April9
article has the wrong hash/field for substitution. Chimera's October16 revision
charges complete Spartan proving. The new IOPP2026/391 screen is HVZK for a
different protocol and gives no license to remove native masking. ICICLEv4.0.0
version commit6c77775961b0e4dc2be359feec1ac11536c18043 and MIT license body were
inspected; release year is not exposed. A same-day turboblake1.8.7 date is from
primary registry search metadata only; direct code/license/commit access failed,
so its CLI compatibility and performance are unverified. BLAKE3's1.8.7 release
date is now verified as2026-08-20 from the primary crate page, resolving prior
unknown-year records without altering them. FlatMerkle's primary URL failed;
mirror claims are not credited. No author benchmark reproduced, foreign code
executed, dependency installed, or access blocker bypassed.

New completed, independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context and accelerator: **none**. Device: one Intel
Core Ultra9 185H CPU worker. Witness/proof/serialization/verification clocks,
startup and initial-prefill duration, startup fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain authorized;
attention can grow quadratically with context. The complete private8B >=50 proved
tokens/s target on RTX5090 or a named high-end GPU remains unachieved.

Carried historical baseline, not rerun/reverified: nonDD8B T128/L32, one16-thread
CPU pass, GPUoff,total478.737s=0.267370positions/s;prove_run393.785s includes
witness98.348s/load17.595s. Seal84.824s overlaps, not additive. Receipt922711264B;
freshverify42.709s+load13.681s;recheck34.395s+load10.739s. Startup fraction,
isolatedserialization and steady slope unknown. No high-endGPU or8B privacy claim.

Next owner action: measure column-hash completion,D2H,salt,first-level,upper-tree
and path-gather exposed clocks with enclosing commitment and whole verified pass;
then the fixed-context resident1/2/4/8 sweep under shared build/heavy locks. Test
this patch only if a material removable salt/first-level fraction exists.
Next local action rotates to sumcheck/GKR: pin the five native slot constructors
and audit which public-shape preprocessing is repeated per proof versus already
resident, preserving fresh CFS masks/challenges. First consult prior metadata
and fraction-tree negatives; avoid rediscovering existing caches. Record removed
public work and added staging, and gate any native timing behind owner locks.

Only research outside runtime written; no production/Git/receipt/calibration/
instruction/reviewer mutation, native build,GPU,install,external write/message,
purchase or escalation. Main/Claude reviews and integrates; no merge here.
Saved reports are not evidence of user-message delivery or supervisor liveness.

Reproduce from the research directory:

```sh
python3 experiments/commitment-salted-merkle-20261026/run_bounded.py probe.py
python3 experiments/commitment-salted-merkle-20261026/run_bounded.py audit.py
```
