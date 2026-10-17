# Retaining roots without retaining full PCS codewords

Scope: source inspection and a small **test-only** differential prototype in
the isolated `/tmp/zk60-sol-model-20260927/zkp-core`. The baseline being
analysed is `/tmp/zk60-groups-20260926`, with source pins in
`layout_source_pins.txt`. A separate keyed GPU candidate's second attempt
passed resident, streamed, compact and tagged full rung-G correctness;
its independent legacy gate remains pending. This note neither reviews
that candidate nor edits its source.

## The exact reuse seam

`zkp-core/src/pcs.rs::commit_zk_owned_with_tag` draws **all** per-row pads
and per-column salts before encoding, builds the encoded matrix, hashes
every encoded column under the profile's COLUMN tag, salts the leaves under
the LEAF tag and builds a NODE-tagged Merkle tree. It returns a
`CommittedZk` retaining raw `data`, `pads`, `salts`, `tree` and the full
`Store::Host { encoded }` vector. The root is complete at that point.

The only later read of that host `encoded` vector is in `open_zk` after
it has formed claim groups, drawn each group's lambda and the proximity
rho, folded **raw data and pads** into clear vectors, absorbed those
vectors, and sampled column indices. It gathers the sampled columns at
`pcs.rs:1038-1050`. `fold_rows_multi_zk` uses `cmz.data` and `cmz.pads` on
the host path; it does not need `encoded`. `protocol.rs` commits A, M and H
before the slots, then opens M, A and H. `run.rs` keeps each hidden boundary
until its joint opening; the same PCM owner shape applies to it.

Therefore the full codeword may be released **after its root exists** and
the queried columns deterministically re-encoded **after** the indices are
drawn. Keep the exact raw data, fresh pads, salts, immutable Merkle tree,
parameters and hash tag. Recompute every row with `encode_row_zk`, gather
the sampled indices in transcript order (including duplicates), then attach
the original salts and paths. No challenge, blinding coefficient or
commitment randomness is redrawn. The one-opening owner discipline and
mask-site checks must remain intact. The test-only prototype in
`recompute_probe.rs` actually drops the encoded `Vec` after a tagged root;
its recomputed opening bytes, transcript state and next challenge equal
the ordinary path, and `verify_zk_tagged` accepts the result. The test uses
a four-row fixture with a masked claim and a proximity mask; changing one
retained data word or one retained pad after the root makes the verifier
reject the recomputed opening. It passed with
`cargo test --offline --locked -j 2` under `/tmp/zk-build.lock`;
`recompute_probe.log` records the result. This verifies the opening seam,
not a production memory peak or a complete block.

Production still needs an API change. Today `Store::Host { encoded }` is
assumed nonempty by `open_zk`; simply clearing it would panic. A narrow
versioned path could add `Store::Recompute` (or an `EncodedStore` whose
`columns` can access the immutable data/pads) and pass a canonical NTT
table to the opener. The test helper shows the arithmetic. Check every
recomputed column's tagged leaf against the retained Merkle tree before
publishing the receipt, then keep fresh-process verification and tamper
controls. If the raw data or pads change after the root, refusal is required.

## Memory and work price from the constructor counts

The figures use the **unregistered Mistral geometry probe** from
`layout-readiness.md`, not an admitted 8B proof. One data row is 128 KiB,
one rate-4 encoded row is 512 KiB. The source's `encode_rows` parallelizes
by row but allocates the whole encoded matrix before returning.

| Retained/live payload floor | T512 | T1024 |
|---|---:|---:|
| A + H + M encoded + two boundaries, current materialized path | 25.70 GiB | 70.57 GiB |
| Same after releasing both A/H codewords after their roots | **5.35 GiB** | **14.57 GiB** |
| During H commitment after A's codeword release, if H still materializes fully | **16.60 GiB** | **46.00 GiB** |
| A + H codeword bytes avoided in the retained set | 21,844,459,520 B | 60,131,115,008 B |
| Queried A + H column payload at Q=256 | 85,329,920 B | 234,887,168 B |

The second row is a retained-set floor, not the run's maximum: before the
drop, A commitment overlaps with the witness and looked columns; the H
commit still allocates its entire codeword. T512 may gain enough headroom
for a single 32 GiB device/host schedule, subject to actual tier placement,
weights, witness, scratch and runtime measurements. T1024 **still exceeds
32 GiB during H commitment** under this drop-only change. The CPU host
baseline also exceeds its historically 15 GiB RAM at T512 during H commit.
These sums are not GPU/host co-residency claims.

Opening recomputation costs one additional full A and H encoding pass per
block: at least 21.84 GB of encoded-row output processed at T512, 60.13 GB
at T1024, plus the corresponding NTT work and queried-column writes.
Across 32 blocks those extra encoded bytes are roughly 699 GB and 1.92 TB
per pass. Encoding time has not been measured here, so no tokens/s forecast
is justified. A GPU path would need to keep keyed hashing and encoding
byte-identical to the CPU oracle and count transfers separately.

## Test-only streaming root construction

To remove the H-commit peak, compute Merkle leaves **while streaming encoded
rows**. A canonical keyed BLAKE3 hasher per encoded column can absorb each
row's 8-byte field word in row order. Then the `hash_columns_keyed` digest
is unchanged: it hashes exactly the concatenation of each column's row
words. At `log_cols=14`, inverse rate 4, there are 65,536 encoded columns.
`size_of::<blake3::Hasher>()` on this build is 1,920 bytes, so all hasher
states require ~120 MiB; one encoded row is 512 KiB, plus NTT scratch,
leaves and the Merkle tree. Chunking several rows changes only workspace
size, provided every column's bytes reach its hasher in the original row
order. Preserve pads/salts drawn before any encoding, and the COLUMN,
LEAF and NODE hash tags. Once the root exists, discard the streaming
hashers and later recompute sampled columns as above. A keyed device
implementation should keep the incremental hash state on its own memory
tier; returning every encoded row to the CPU would impose a large transfer
bill.

The isolated `pcs/recompute_probe.rs::stream_commit` now implements this
schedule **only inside a test module**. It draws pads and salts in the
materialized constructor's order, encodes bounded row chunks, updates one
keyed COLUMN hasher per encoded column in row order, then applies the
original LEAF and NODE keys. Its retained `Store::Host` has an empty
encoded vector and can be opened only by the separate test recomputation
helper. Production `open_zk` still assumes a full encoded vector; this
prototype is not a new API or an admitted profile.

The eight small seeded cases cover legacy and tagged keys, 2/3/5/9 rows,
32/64 encoded columns, chunk lengths 1/2/3/4, several pad lengths
including `q=16 > n=4`, randomized fixture mask and proximity rows, and
duplicate sampled indices. Every unsalted leaf, salted Merkle level/root,
pad/salt and post-commit RNG continuation matched the materialized CPU
oracle. Full opening bytes, prover/verifier transcript continuation and
verifier acceptance matched. Altered column words, salts, Merkle paths,
retained source data and pads were refused. `stream_commit_probe.log`
records two passing tests; `streaming_source_pins.txt` pins the inspected
source. These tests establish deterministic small-fixture parity, not a
complete private-block receipt or measured throughput.

For the probe cases, `size_of::<blake3::Hasher>()=1,920` bytes. The column
hasher vector occupied 61,440 or 122,880 bytes; the encoded chunk buffers
occupied 256–2,048 bytes. At the unregistered Mistral geometry of 65,536
encoded columns, the same hasher vector would be 125,829,120 bytes
(120 MiB), plus 524,288 bytes per buffered row. Those are named buffer
sizes, not total process or device peaks: raw rows, pads, salts, Merkle
nodes, NTT work and caller-owned tensors remain live. The construction
still encodes the full A/H matrix once for roots and again for queried
openings; recomputation trades retained codeword bytes for that second
pass and high column-hasher state. A production implementation needs a
compact owning store, exact commitment/opening lifecycle review, a
small-shape RSS/VRAM and transfer measurement, complete private-block
freeze/tamper gates and a real trained-block clock before any 5090
feasibility or tokens/s claim.
