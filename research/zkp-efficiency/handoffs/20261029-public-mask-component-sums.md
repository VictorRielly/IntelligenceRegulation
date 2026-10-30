# Prepared public sums: exact component, parked pending native clocks

Run `20261029T105649Z-8532a02d`, October 29, 2026 UTC.
**No native proving speedup measured. Do not integrate unconditional eager
preparation on the strength of these diagnostics.**

The baseline is prior paired3 arithmetic with cached public Eq coefficients.
For each fresh private pair `(x,y)` and public coefficient `(a,b)`, it computes
three dot accumulators and returns `(A+7B, C-A-B)`. The candidate prepares only
the canonical public `a+b` values once. It retains every private read and
product; all public preparation is scoped to the current invocation.

The compiled component interface is
`PreparedWeights::new(point: &[Fp2]) -> PreparedWeights`, followed by
`dot(&self, point: &[Fp2], xs: &[Fp], ys: &[Fp]) -> Fp2`. It owns the public
point, Eq and sums, checks the complete ordered point and lengths, and stores
no private data or result. The control has the same public point ownership
and checks. The installed original evaluator, prior paired3 and prior
public-tail cache must remain separate comparisons until actually integrated.

Patch location: [candidate.rs](../experiments/public-mask-component-sums-20261029/candidate.rs).
It is a compiled research helper, **not an applied production patch**.
Native seam: `ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs`,
`mask_eval` at line 405 and the ordered `Tab::Priv` mapper near line 618.
Preserve commitment-specific row width, exact tail, `c0`, distinct original
reserved-pair identity, logical output order and all later zero extensions.
Caller cache/dispatch integration was not implemented or compiled here.

Validation: 792 synthetic fixtures, 3,168 terminal comparisons, 9,216 direct-Eq
values and ten negative controls pass. The original native function is
extracted with stub metadata; field code is unchanged; Eq construction is
serialized. Independent MSB-fold/schoolbook-u128 and direct-cube references
cover general extension, Boolean/zero/maximal points, unequal endpoint widths,
offsets and fresh changed private data. Source/extraction/count audit: 91
checks, eight static mutations and eight pinned sources pass. Full commands,
source/binary hashes and initial audit-anchor failure are retained in the
[experiment](../experiments/public-mask-component-sums-20261029/README.md).

The old norm4/sigma3/P2 T128 catalog saves 1,940,224 public additions per block,
adding 33 allocations and 31,389,696 logical memory-access bytes. Maximum
extra live sum payload is 128 KiB per active context. No actual R13 LOW+h24
incidence, physical DRAM traffic, exclusive phase time or native peak is known.
The 16,384-wide one/two-pair timing diagnostics regress; higher reuse differs
only slightly on the shared box. No complete-proof improvement follows.

First measure exclusive Eq construction, mask dots, extension work and enclosing
proof time on the actual admitted profiles. If material, compare original,
cached paired3 and prepared variants under current shared build/heavy locks,
including preparation and drop. Skipping single-use groups is analytically
better but was not implemented or timed. A two/four-pair register tile could
avoid the sum buffer, but adds accumulator/register pressure and remains only
a question. Whole-prover high-end-GPU and verified resident 1/2/4/8 workloads
retain priority; this handoff queues no heavy job.

Unresolved gates: native release/compiler behavior, complete layout/refusal
semantics, parallel callers, RNG schedule, transcripts, extension messages,
PCS, independent full receipts and privacy. There is no authority to reuse
masks, private openings, pads or salts across proofs. Falsify on any exactness,
ordering, refusal or security mismatch, or no enclosing verified-workload gain.
Main/Claude owns review and integration; nothing was merged.
