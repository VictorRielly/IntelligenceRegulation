# Keyed GPU chunked PCS memory audit (source-only, 2026-09-27)

Scope: read-only inspection of `/tmp/zk60-sol-gpu-20260927`, using the
**unregistered** Mistral geometry counts in `layout_account.json`:
`T=512/1024, d=4096, f=14336, H=32, Hkv=8, dh=128`, `n=16384`,
`nn=65536`, `Q=q=256`. This is the historical 7.24B-parameter proxy,
not Victor's literal >=8B trained target. No large allocation or GPU run
was made here. Source hashes are in `gpu_chunked_source_pins.txt`.

## The actual route

`private_block/protocol.rs:798-858` constructs A as a host `Vec<Fp>` and
passes it by value to `pcs::commit_zk_owned_tagged`; it remains in
`CommittedZk.data`. H is likewise host-built at lines 884-977 and passed
by value. The backend in `gpu/mod.rs:640-675` offers tagged commitments to
`dev_commit_zk_keyed`; on success, the CPU core stores `Store::Device`,
while retaining the host data, pads, salts and Merkle tree. If CUDA is
disabled or declines, the same core constructor falls back to the full
host encoded matrix. That fallback must be kept distinct from the GPU
case, especially for capacity claims.

`gpu/cuda.rs:3638-3784` uploads a **second, full raw data matrix** for each
commitment. With `HL_ZK_CHUNK=force`, or auto once `rows*nn*8` exceeds the
default 1 GiB threshold, it calls `commit_zk_chunked`. Both probe sizes
are above that threshold. The chunked route never constructs a full
encoded matrix: `DevCommit { data: d_data, enc: None, zk: Some(...) }`
retains device raw rows, device pads and coset powers. `commit_zk_chunked`
uses chunk-sized coefficient, pad/scale and encoded scratch, plus a
per-column BLAKE3 CV state and leaf buffer; the host builds the salted
Merkle tree from downloaded leaves. This is already the production-capable
GPU candidate seam; the separate CPU test-only streaming prototype does
not add that capability or make this candidate an accepted production path.

At opening, `zkp-core/src/pcs.rs:1016-1046` folds message rows through
the device store and pads through **host** `cmz.pads`, then asks the store
for sampled columns. `gpu/cuda.rs:3005` dispatches `enc=None,zk=Some` to
`columns_chunked_zk` (1881-1960), which re-encodes through the retained
pads and coset powers in chunks and gathers into a device `rows × unique
queries` buffer. It copies that buffer to a host `Vec<u64>`, then creates
the returned `Vec<Vec<Fp>>`; duplicate queries reuse one device slot but
still receive a full host column each. `protocol.rs:982-1009` retains A/H
through the 23 slots, opens M, then A and H, dropping each owner after
its opening. The slots read `a.data` and `h.data`, so simply clearing those
host vectors before the slots would change the current interface.

## Named payload obligations, separately by tier

The numbers use *length × element size*, not allocator capacity or
measured RSS/VRAM. A/H data below excludes M, boundaries, model weights,
witness, runtime and proof buffers.

| Live payload | T512 | T1024 | Tier |
|---|---:|---:|---|
| A raw data | 2,442,264,576 B | 6,594,887,680 B | host **and** device; upload duplicates it |
| H raw data | 3,018,850,304 B | 8,437,891,072 B | host **and** device after H commit |
| A+H pads | 85,329,920 B | 234,887,168 B | host **and** device |
| A+H coset powers | 1,048,576 B | 1,048,576 B | device, two retained copies |
| A+H salts and Merkle nodes | 12,582,848 B | 12,582,848 B | host |
| A+H retained host PCS, **no codewords** | 5,559,027,648 B (5.18 GiB) | 15,280,248,768 B (14.23 GiB) | host |
| A+H retained device raw/pads/powers | 5,547,493,376 B (5.17 GiB) | 15,268,714,496 B (14.22 GiB) | VRAM |
| Host A+H PCS plus materialized M and two boundaries | 5,749,434,240 B (5.35 GiB) | 15,638,951,808 B (14.57 GiB) | **conditional host** floor; M/boundaries may use device stores |

The prior 25.70/70.57 GiB A/H/M/boundary totals are valid for the
**materialized host baseline or CUDA decline**, not the accepted chunked
GPU route. In the latter, A/H encoded matrices of 9.77+12.08 GB (T512)
or 26.38+33.75 GB (T1024) are absent from retained host and VRAM stores.
Do not add the 5.18-GiB host and 5.17-GiB device sets as if they share one
memory capacity; they are duplicated payloads in distinct tiers. M and
boundaries need separate route checks before treating their earlier host
materialization as a GPU-path fact.

With the default 128-row chunk and full-width pad/scale, one active
commit/open scratch set is: 16,777,216 B coefficient + 67,108,864 B
pad/scale + 67,108,864 B encoded chunk + 50,593,792 B BLAKE3 CV state
(`B3_STATE_SLOTS=193`, `nn=65536`, 4 B/slot) + 2,097,152 B leaves
= **203,685,888 B (194.25 MiB)** during commitment. The compact-pad
switch changes only the pad/scale buffer to `128*(n+q)*8 = 17,039,360`
B, making this named set **153,616,384 B (146.5 MiB)**. Hash key, NTT
tables, CUDA context, pool capacity and launch allocations add more.
During opening, hash state/leaves are absent; the same three encode
buffers are accompanied by a `rows × unique queries × 8` device gather
buffer, at most 38,160,384/47,169,536 B for A/H at T512 and
103,045,120/131,842,048 B at T1024. The host has a downloaded `Vec<u64>`
and returned column vectors, potentially two copies of those gathered
words transiently, plus rho and folded clear vectors. `Pooled::take_min`
may reuse a larger cached buffer; the source also retains allocations in
its pool, so these are lower bounds on actual device occupancy.

## What remains binding

The **host** builds H while retaining A, the witness and looked-up
columns. Before `drop(looked); drop(wit); drop(deltas); drop(act_idx)` at
`protocol.rs:929-932`, the counted A/H raw data plus those four host
collections alone are 10,587,357,184 B (9.86 GiB) at T512 and
29,177,053,184 B (27.17 GiB) at T1024. A pads, M, neighboring boundaries,
histograms, lookup helpers and allocator overhead increase that peak.
After the drops, the A/H raw rows still remain on both tiers for slots and
openings. Thus T1024 is already beyond the current host's historically
~15 GiB during H construction; a 5090's 32 GiB VRAM does not solve host
RAM. Even T512's current 8 GiB GPU must hold ~5.17 GiB A/H device source
plus scratch, M/boundaries, model data, witness GPU scratch and runtime;
its actual fit is unmeasured. At 32 GiB VRAM, the retained A/H chunked
payloads themselves fit for T512 and T1024, but neither total block peak
nor 50 proved-token/s follows.

The next memory work is an end-to-end measured tier/lifetime ledger at a
small admitted shape and a host A/H/witness schedule. In particular,
preserving the source bytes needed by the slots while avoiding both full
host and device raw copies (or spilling one tier safely) matters more than
another streaming commitment implementation. Production must also make a
GPU decline fail closed for any run that claims chunked GPU capacity, and
measure pool occupancy, host RSS, transfers and clocks before scaling.
