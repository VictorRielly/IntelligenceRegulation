# Exact int16 FFN-down witness through integer byte products

Run `20261004T040146Z-c6dec297`, cycle0022, 2026-10-04. Research-only prototype;
production is read-only. No native build, GPU, dependencies or proof ran.

The bounded experiment passes. All65,536 int16 values (393,216 scalar
products),42 direct/split dot cases with192,132 terms up to K=16,384,
72 padded matrix cases/1,680 output words,6,162 requantization cases and106
ordered FFN suffix cases agree with independent references. There are17
mutation controls plus2 invalid-int16 domain controls.98 suffix fixtures
are accepted by the synthetic relation;8 refuse at their expected sites.
These are arithmetic fixtures, never accepted proofs or proved tokens.

The final run used one pinned, low-priority Intel Core Ultra9 185H thread,
0.659741 seconds,16,900 KiB peak RSS,64 MiB estimated allocation budget,
512 MiB RLIMIT_AS and59-second alarm. CPU only; Python3.10.12. Seed2026100422.
Exact command, exit0 and logs are retained. Three earlier passing revisions
are preserved: clearer negative-control labels, then a computed reordered
first-refusal mutant replaced a constant-only comparison; then an actual float-output mutant was added. No timing result
from these revisions is a GPU or implementation speed measurement.

## Baseline and exact interface

Pinned source: `ops/zkp-mvp/candidate/hashline/src/private_block/witness.rs`,
`matmul` line300 and `matmul_in_out` line312; FFN-down call line685.
The down input `h16` has already passed the product's inclusive int16 check.
Weights are signed bytes in input/output row-major order. Dot products remain
i64 until `quantize(..., SH_Z=6, -32768,32767,"FFN down")` computes the
rounded value and biased remainder. Residual2 follows only after down passes.

For every signed int16 x, define l=(x&255)-128 and h=x>>8, both signed bytes.
Then x=l+256h+128, so each output dot is
`dot(l,w)+256*dot(h,w)+128*sum(w)`. The Python candidate models two byte GEMMs
and one stacked `[l;h]` GEMM with2M rows. Each returns exact i32 partials;
reconstruction widens each operand to i64 BEFORE multiplying/adding.
At public padded K<=16,384, each partial has magnitude<=2^28, the column sum
<=2^21 and the original dot<=2^36. The latter does not fit i32.
Larger shapes need bounded K tiles or unchanged fallback, not a new refusal.

Independent references: checked direct i64 accumulation follows the separately
pinned `private-block-kernel/src/lib.rs:346/363`; quotient/remainder uses floor
division rather than the candidate's arithmetic shift. Exhaustive scalar
packing also agrees with independent signed byte decoding. Dense and padded
references use both weight orientations. The suffix begins at supplied
gate/up accumulators: norm, attention, their weight GEMMs and native witnesses
are outside scope. Its checks retain gate before up before activation/product
before down before residual. It is not full-block equivalence.

Padding matters: zero maps to l=-128,h=0. True token rows read the full padded
K, as the native helper does. Padded token outputs stay zero; padded output
columns have structurally zero weights in valid profiles. A dirty internal
K coordinate is included by both helpers rather than silently discarded.
Neither a helper assertion nor a dirty fixture admits a padded native proof.
Model/weight identity and the exact consumed K must bind any cached sums.
P1 public sums can be preprocessed; P3 sums remain secret. No masks, transcript,
commitments, openings or proof rows are reused or changed.

## Eliminated work, added costs and ceiling

The hypothesis removes CPU FFN-down direct int16/i8 dot work when a device
route wins. It does not reduce the number of scalar products: two byte dots
replace one wider dot. Stacking may save one launch per down matmul; device
weight reuse and speed remain unknown. Column sums are a small, safely
reusable weight computation subject to immutable identity binding.

Costs include packing, weight sums/upload, twice the byte MAC work, exact i64
reconstruction, downloads, synchronization and BLAS workspace. Count-only
Llama3-8B metadata at T512, padded K16,384, N4,096 gives16 MiB packed input and
16 MiB partial outputs (32 MiB additional scratch before workspace),16 KiB
column sums and64 MiB padded weights. Existing64 MiB i64 input and16 MiB i64
output remain. The two-call route may reread weights; a stacked call does not
prove a reduction in device traffic. This geometry is not an admitted profile.

For accepted workload positions P, ceiling is
`P/(T-C_down_all_builds+C_pack+C_upload+C_byte_GEMM+C_i64+C_download+C_sync)`.
No accepted8B term is measured; no numeric target projection follows.

New clock correction: the run starts `Phases` before boundary preparation and
`src.witness(k)`. Its first mark occurs only after A allocation/conversion.
Thus the historic86.691-second first-mark parent includes stage prefix,
boundary work and witness construction, not just A writes. The initial chain
build also computed and dropped12 witnesses, with73.36 seconds including
setup/census. Current sources establish the control flow; source/binary
identity with the historical timed ELF is not established. Preserve prior
raw clocks but withdraw allocation-only attribution. The old408.609226-second
diagnostic would still take248.558226 seconds even if BOTH entire parents
vanished at zero cost (arithmetic2.059880 positions/s). This is an extremely
loose parent-deletion bound, not candidate savings or countable throughput.

Falsification: any accumulator/remainder/padding/refusal/native witness-byte
mismatch; integer accumulation/epilogue overflow or float conversion; stale
column sums; any native RNG/transcript/receipt difference; or total new device
work+packing/transfers/sync>=the replaced CPU down cost. Unmeasured clocks
falsify a numeric speed claim, not the arithmetic hypothesis.

## Evidence and next experiment

`source-pins.json` binds read-only source snapshots; `source-records.json`
contains6 LIVE primary records with dates, exact URLs, inspected license and
commit qualification. Literature suggests integer slicing and offset sums;
vendor release titles/numerical-emulation accuracy do not establish our
integer-exact witness or complete proof throughput. CUTLASS license and
gemmlowp history access errors are retained. No downloaded scripts executed.

Owner next: add isolated matched-build clocks around initial chain build,
per-stage boundary preparation, witness build, FFN-down, A allocation/fill,
serialization and sink. Then validate an exact integer device adapter under
the shared heavy/GPU locks, with full witness/receipt bytes, fresh masks and
independent complete-stack verification. This lane launches neither step.
Next local cycle: bounded tile/recombination and streamed down+requant output
oracle across K boundaries, both orientations, full support and first refusal;
investigate reducing partial-output scratch without changing bytes.

This cycle0 accepted full-stack passes/0 countable tokens; context null.
Steady/total rates,startup fraction,witness/proof/serialization/independent-
verification clocks,latency/lag/drain are unmeasured. No prefill,resident-pass
or decode proof. Larger workloads remain permitted; longer context retains
quadratic attention obligations. >=50 proved-token/s private8B is unachieved.
