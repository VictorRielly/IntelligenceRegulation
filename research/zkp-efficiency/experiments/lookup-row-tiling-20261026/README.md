# Fresh encoded lookup rows — cycle 0127

Run `20261026T192925Z-2a61ec3c`, 2026-10-26 UTC.

No proving improvement measured. The bounded experiment checks an exact
constructor optimization: encode at most 256 public exp or activation rows
using the current proof's beta and gamma, then repeat the initialized output
prefix into the lifted table domain. No encoded row survives the call.

The existing native `eq_cube` already uses `Vec::extend_from_within`. The
research patch applies that pattern to two other constructors, with a bounded
final copy for arbitrary lengths. It reserves the output once, adds no second
prefix buffer and performs no explicit zero fill. This describes proposed Rust
source, not observed allocator behavior or compiler output. Python slicing in
the model creates temporary storage and is not a Rust memory measurement.

The candidate is uncompiled and unapplied. Production sources were read only.

## Evidence and limits

`probe.py` passes **3,353 checks**, 204 constructor cases, 2,264,184 compared
output entries and identical diagnostic little-endian bytes. Six seeded
fixtures cover beta zero, base and extension values, boundary gamma, checked
range/monotone synthetic exp values and signed i16 activation boundaries.
Raw helper conversion tests also cover i64 minimum and maximum; those exp
values are deliberately outside the admitted public constructor's domain.
They test helper arithmetic, not a newly admitted profile.

Lengths: 0, 1, 2, 7, 255, 256, 257, 511, 512, 513, 1023, 1024, 4096,
16384, 32768, 65536 and 65537. Every copy schedule from length 0 through 1024
is checked independently using integer row labels. Forty-eight malformed
adapter cases test lazy indexing and untouched zero-length calls. Native
activation tables have a fixed `[i16; 256]` type; malformed activation lengths
cannot arise through that type. Public construction/shape checks remain
outside the optimized helper and are not bypassed.

For all 256 choices of alpha equal to an encoded row, the same zero-denominator
positions remain, including lifted duplicates. No inversion/refusal pipeline
ran. Thirty direct original-cube MLE checks at arbitrary **base-field** points
match a separate fold evaluator; extension-field evaluation points are owed.
Thirteen controls detect stale beta/gamma, table changes, exp/act confusion,
modulo 255, unbounded lifted indices, missing extension coordinates, shifted
prefixes, stale diagnostic bytes, eager malformed reads, signed-min errors
and missing padded denominator zeros. SHA256 is diagnostic only.

The reference uses direct integer coordinate projections and an independently
expanded Boolean basis; the literal/candidate use generic Goldilocks Fp2
operations with u²=7. Both implementations were authored locally: algorithmic
independence, not an independent native prover. No native Rust, CFS, PCS,
transcript, mask, receipt, GPU or privacy test ran.

`audit.py` passes **158 checks**, pins nine native files and compares current
source hashes. It checks pair arithmetic in R12 and the older GPU branch,
native incidence, existing length/refusal and full-table inversion seams,
proposed safe ranges, patch construction and operation/traffic counts.
No tested source drift was observed in that audit.

## Cost and integration boundary

Let L be the lifted table length and q=min(L,256). Across the exp/act pair:

| Source-level quantity | Baseline | Candidate |
|---|---:|---:|
| Fp2 products | 2L | 2q |
| Fp2 additions | 4L | 4q |
| Signed-to-field conversions | 4L | 4q |
| Output payload | 32L B | 32L B |
| Extra separate prefix scratch | 0 | 0 |
| Prefix copy reads | 0 | 32(L−q) B |
| Raw public-table loads | 10L B | 10q B |

At R12's T128 L=16384: **32,768 → 512 products**, **65,536 → 1,024
additions/conversions**, six copy calls per constructor. Pair output remains
524,288 B. The pair adds 516,096 B of copy reads while removing 161,280 B
of raw table loads: **354,816 B more logical reads**. These are payload/API
counts, not DRAM transactions, instructions, bandwidth or speed. Hot raw
tables and compiler elimination of multiplication by a base-field value can
reduce the apparent advantage. There is no lower output allocation or peak
memory claim.

For one source-counted 32-block R12 T128 argument invocation, 1,032,192 Fp2
products are removed and 16,515,072 B of copy reads are added. This is one
SC_TAB definition per block. Proving, its verification and each later
verification are separate invocations; their clocks are never added blindly.
T32/T64 use L=8192. This native R12 door does not admit T512. The selected
R13 LOW+h24/per-group fidelity changes are excluded from these counts.

The three H helper wrappers use the original 256 rows: **no arithmetic is
removed there**. Their full public-table inversions and zero checks remain.
`Tab::Pub` already moves its vector into proving tables; do not claim an
additional downstream clone removed. All dense private scans/folds, private
helpers, fresh masks, commitments, openings, pad-zero checks, witness work,
transfers, serialization and full verification remain.

Seam: canonical `ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs`,
`table_values_exp_at` / `table_values_act_at`, around lines 1132/1143 at the
snapshot. `row-tiling.patch` and `candidate-argument.rs` are research artifacts.
The earlier GPU branch has matching constructor expressions; no native GPU
compatibility or inherited FZC incidence follows.

With unknown removable critical-path fraction f, even free deletion is bounded
by 1/(1−f), before copy/dispatch costs. No numeric complete-GPU rate follows.
Falsify on any field/index/coordinate/byte/challenge/table/length/refusal/RNG/
transcript/privacy mismatch, compiler-erased baseline cost, negligible native
constructor incidence or slower enclosing independently verified workload.

## Ranked queue and literature

All 39 earlier hypotheses remain in `hypotheses.json`. Ranks 1 and 14 were
refined, and 40/41 added. Top priorities remain:

1. Owner whole-prover high-end GPU and independently verified fixed-context
   resident workloads of 1/2/4/8 passes: complete recurring work, fit,
   transfers, fresh masks, serialization, startup and drain must be measured.
2. Owner DD scaling at larger admitted context with the cheapest passing
   fidelity stack: the earlier T128 null timing is preserved; different
   context geometry, profile binding and privacy gates remain prerequisites.
3. Exclusive whole-proof phase and actual capacity clocks, including failures
   and cleanup: measurements must identify a material critical-path cost.

The leading locally feasible question was rank14; the top three need owner
device/build windows. This small candidate stays parked for native clocks.
New rank40 screens the older Celer protocol; rank41 asks whether the existing
public descriptor work can handle this actual periodic SC_TAB seam without
materializing the lifted public cube, including extension and terminal rules.

Nine initial native LIVE result batches plus a tenth date check are retained.
Seven primary source records append the ledger from 814 to 821. Sources:

- [Celer paper](https://eprint.iacr.org/2026/1453), newly assessed older work:
  received 2026-07-16, revised 2026-07-21. It reports fewer commitments for
  many-query workloads; its performance was not reproduced. The
  [prototype PCS](https://github.com/quwenjie/Celer/blob/main/dory_pcs.hpp)
  uses BN254/mcl pairings and explicitly omits blinding. That implementation
  fails the privacy compatibility filter. Restoring/accounting for hiding
  and new bindings is prerequisite to any future study. PDF 403, commit
  history and license cache misses are recorded; code/license dates unknown.
- [SP1 releases](https://github.com/succinctlabs/sp1/releases): current
  v6.10.0/October23, with inspected full commit
  `d83ed91f96701209613720708f36ffce0e98ed33`. Its release notes establish
  version/shard-recovery changes, not a speedup here. Registry search renders
  6.10.0 dated 2026-10-23 while direct `latest` renders 6.9.0; exact GPU crate
  source and license bodies were inaccessible. Do not treat metadata as a
  compatible Goldilocks private prover implementation.
- [Logup* author PDF](https://levs57.github.io/logup_.pdf): newly inspected
  copy of an already assessed protocol; table-sized weighted counts add new
  sumchecks/bindings. The primary ePrint history dates are retained. TenseUp's
  primary refresh was inaccessible; mirror search snippets are discovery only.
- [Rust API](https://doc.rust-lang.org/std/vec/struct.Vec.html#method.extend_from_within):
  checked safe copying and version boundary. This native API pattern was
  already present in `eq_cube`; no third-party implementation was executed.

The rotation covered lookup/softmax, public memory traffic and amortization,
with sumcheck/PCS privacy filters. Next local work returns to the native
periodic-table round/terminal boundary; retain GPU NTT/commitments,
quantization/arithmetic and proof composition in the rotating queue.

## Commands, clocks and target status

Seed: 202610260127. One pinned Intel Core Ultra 9 185H worker, nice19;
30-second CPU/alarm, 35-second parent timeout, 256 MiB AS cap; estimated
experiment memory 96 MiB. No GPU use. These shared-box clocks measure checking:

```
python3 experiments/lookup-row-tiling-20261026/run_bounded.py probe.py
python3 experiments/lookup-row-tiling-20261026/run_bounded.py audit.py
```

Model: 9.169534 s, 56,076 KiB RSS. Source audit: 0.010463 s, 16,976 KiB RSS.
Commands, exit codes and code hashes are in `commands.jsonl`; source pins
are in `native-pins.json`. Full source ledger and prior memory are in startup.

New completed independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context / accelerator: **none**. Witness, proof,
serialization, verification, startup and prefill clocks; startup fraction,
proof bytes/latency, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Longer
workloads remain authorized; attention can grow quadratically with context.
The complete private 8B / >=50 proved tokens/s high-end GPU target remains
unachieved. The classifier application's later direction does not amend it.

Historical diagnostic carried, not rerun or reverified: R8/nonDD 8B T128,
L32, one 16-thread CPU pass, GPU off; total478.737s=0.267370positions/s.
prove_run393.785s includes witness98.348s/load17.595s; seal84.824s overlaps.
Receipt922711264B; fresh verify42.709s+load13.681s, recheck34.395s+load10.739s.
Startup fraction, isolated serialization and steady slope unknown. No GPU
or 8B privacy acceptance follows from that diagnostic.

Owner next: exclusive constructor/SC_TAB/enclosing native clocks, compiler
inspection, native field/golden/refusal/privacy gates if material, then
independently verified fixed-context resident1/2/4/8 under shared locks.
No heavy job queued here. Main/Claude reviews and integrates; no merge.
Only research outside runtime written; no production, Git, receipt,
calibration, instruction, reviewer or safety-gate changes, installations,
GPU jobs, foreign code execution, external writes/messages or escalation.
Saved reports do not establish message delivery or supervisor liveness.
