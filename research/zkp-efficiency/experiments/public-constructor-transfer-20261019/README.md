# Checked public constructor transfer — cycle0086

Cycle0086 — `20261019T181854Z-f5bd1f03` — 2026-10-19 UTC.

**No speed improvement measured.** Checked public ownership transfer matches
48 synthetic layouts and preserves tested refusal/encoding outcomes. Native
R8 source shows12 vector clones totalling243410944B per8B T128 load that an
owned constructor could avoid. The512B inline activation copy remains.
No native code was modified, built or proved; proposed patch is unbuilt.

Main PASS 7074 assertions / 2200 rejected mutations;
independent audit PASS 1871 assertions /624 output-corruption controls.
Main/audit 12.308901/0.152414s, peaks
30416/26828KiB, one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s/512MiB caps. These are synthetic validation clocks,
not a native constructor benchmark.18 pins unchanged;14 match frozen R8.

The previous pins4+current/next1.360168GiB ledger excluded loader temporaries.
This cycle counts raw/padded/owned buffers, decode/maps, optional RoPE reserve
and full sealing record hash scratch. Enumerated public-payload envelope with
four distinct pins+current+next load, accounting for16 native hash workers:
**2.016689GiB borrowed ->1.789997GiB moved** [MODEL]. One-worker ledger:
1.852619->1.625927GiB. Not actual RSS/VRAM, complete memory or hardware fit;
private witness/proof/device/allocator/page-cache costs remain excluded.
Evicted live leases from prior findings must still be charged separately.

Carried owner R8 CPU 8B diagnostic: T128,32 blocks,one16-thread pass,
GPU off,n=1. Total478.737s (128/478.737=0.267370 positions/s diagnostic),
prove_run393.785s includes witness hand-over98.348s, itself including17.595s
block loads. Sealing wall84.824s includes overlapping27.151s load tasks and
80.897s witness tasks. Do not add nested/overlapped clocks. Receipt922711264B.
Fresh verify42.709s plus initial load13.681s; recheck34.395s plus10.739s load.
Fresh guard wall165.982s includes controls. Startup fraction, isolated
serialization and steady slope are unmeasured. Researcher did not reverify
a receipt; no new target credit. Owner RSS6.69GiB/cgroup9.76GiB includes
existing allocations; do not add this public ledger to those peaks.

New independently verified complete-stack proofs/passes/positions: **0/0/0**;
device none. Target steady-state/total-workload rates, startup fraction and
witness/proof/serialization/verification clocks: all unmeasured this cycle.
No long-context prefill, resident proof series or decode ran. Synthetic48
fixtures are constructor cases, not proof passes. Larger workloads remain
allowed; attention work can grow quadratically with context. Complete private
8B / >=50 proved positions/s on one RTX5090 or a named high-end GPU is
unchanged and unachieved. No fresh masks, private commitments or openings
were reused or changed.

Owner: review the unbuilt two-file patch, then run locked native constructor
byte/refusal/parity gates and isolate allocation/copy clocks before any claim.
Whole-prover GPU and independently verified fixed-context resident1/2/4/8
workloads stay first. Next local: differential direct signed-byte padding
from Array.bytes versus i8s()+pad_matrix (all256 byte values, interleaved
query-head slots, strides, malformed lengths and zero-pad controls). Account
for whether removing58720256B decode scratch changes the dominant full-loader
peak; do not repeat cycle0027's completed public-digest streaming/cache study.


Reproduce (each <=59s CPU/wall,512MiB address space,one nice19 CPU):

```
python3 -B experiments/public-constructor-transfer-20261019/run_bounded.py experiment.py
python3 -B experiments/public-constructor-transfer-20261019/run_bounded.py audit.py
```

Seed2026101986. Six shape patterns repeated with independent random public
fixtures: (query heads,KV heads,head dim,FFN width) =
(2,1,2,5),(6,2,2,11),(12,4,2,19),(8,2,2,16),(3,1,4,9),(12,4,4,25).
Token axis3 is a synthetic table extent, not an admitted native context.
Candidate row-copy/scatter padding is compared with per-destination inversion;
constructor checks use a separate support-set/error-class reference. Separate
audit imports no candidate and reconstructs every byte/length-delimited SHA
encoding from raw public miniatures. Raw signed samples include i8 extrema;
tables are structure fixtures, not the real exp/SiLU/RoPE generators.

Mutation coverage: all13 array lengths, off-support entries for all9 matrices,
interleaved query support, RoPE range/initial row, exp scale/range/order,
act[128] at padded/unpadded FFN, first error class, consumed-wrapper reuse.
624 independent output-corruption controls belong to the artifact audit,
not additional candidate differential cases. Python ownership is a model;
no native Rust ownership, exact native error strings, CS checks or receipt
equivalence was executed. The review-only patch is uncompiled.

payload-ledger.json counts218114560 raw11 bytes,243277824 padded-i8 bytes,
243411456 public bytes at8B T128. Full sealing LayerRecord uses9 parallel
byte conversions;16-worker reservation is their SUM, one-worker reservation
their MAX. Actual concurrency/capacity/allocator/page-cache/private/proof/device
memory is unmeasured. Supports/maps and an optional generated-RoPE extra pair
are reserved. Reload skips LayerRecord and needs a different detailed timeline;
this full-sealing ledger does not claim identical reload overlap.

An avoided copy volume is neither physical memory-bus traffic nor a time
saving. Current/pin blocks are distinct for the reported envelope; evicted live
leases require extra accounting. The inline512B act copy remains. Native
allocation behavior, critical-path savings and high-end GPU memory/throughput
remain unknown. Candidate ceiling and falsification are in hypotheses.json.

Source pins and startup snapshots preserve durable inputs. Initial test/control
failure and scratch-accounting audit failure remain under initial-control-
misclassification/ and before-support-reservation-fix/. commands.json records
exact argv/exits/source hashes; final invocations use distinct numbered logs.
search-log.md and source-records.json retain LIVE evidence/access failures.
No foreign code was executed or dependency installed.
