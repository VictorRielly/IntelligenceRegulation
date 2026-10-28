# Public pad descriptors and first-round eligibility — cycle 0100

Run `20261020T081854Z-6e7df31f`, 2026-10-20 UTC.
**No proving speed improvement measured. No native build, GPU or proof ran.**

The useful result is a source-backed restriction on the prior affine FZC
candidate: **accepted padded FFN descriptors have all eleven nonzero public
pad weights.** Earlier arbitrary support sizes 1/3/8 are synthetic controls,
not outputs of the inspected caller. Unpadded slots have no pad term.
The locally testable question was chosen after reading the current agenda,
status, measurements and prior results; owner GPU/full-workload measurements
still rank above further local arithmetic work.

`zero_rule_a_planes` includes all eleven `Dom::F` A planes. The only named
exemption, `A_E`, belongs to another domain. `SC_FZC` has a single pad group,
draws **nonzero** zeta, and `PadTerm::add` starts at zeta^0. In Goldilocks
Fp2 (`u^2=7`) every resulting zeta power is nonzero. The descriptor writes
these unscaled weights to `FZ_PADW`; `mu_pad` is separate. Zero `mu_pad` is
allowed and makes the derived pad polynomial zero while the existing
parameter weights still number eleven. This is no reason to retry a challenge
or change any refusal. Prepared full-pair coefficients may all be zero in
that case; do not confuse them with the original parameter block.

The conclusion is checked independently in the active GZC source and the
**four inspected public source files** of frozen native R9. R9's DD and
non-DD plane lists both retain eleven FFN planes. This is not validation of
the entire R9 tree or its proofs/privacy gate. The active GZC tree's 8B
constructor admits T32; R9 separately admits T32/T64/T128. **R9's slot arm
does not contain the GZC descriptor adapter.** Geometry correspondence is
not evidence that the newer profiles already run through the old GPU seam.

The caller gates remain intact: BASE requires base-valued A tables 3..13
and support table 20, when present, and is selected only at `next==0`.
Raw requires split, fused and raw switches, n>=3, n-1>tail_log, and resident
Base/Pair sources at every table 3..19. Helpers remain extension-valued.
Only raw && !FOLD phase1b can use the proposed adapters. No new private-value
scan or telemetry, new eligibility, transcript change, or randomness reuse
is proposed.

## Experiment and limits

One-thread Python differential checks compare a source-translated model
against independently expressed predicates and schoolbook quotient-ring
arithmetic, using exponentiation from the mathematical definition instead
of the constructor's power recurrence. The final run passes **7,616 checks,
640 public descriptor/challenge cases, 3,132 gate cases and 46 negative
controls**. Eight zero-zeta padded cases refuse. Ten geometry fixtures cover
toy, 125M, development, TinyLlama T32/64/128, 8B T32/64/128 and an explicitly
synthetic P-3 lift. No large tables are allocated; these are public geometry
calculations, not completed model contexts.

The checks compare canonical relevant parameter bytes and the pad polynomial
on synthetic extension-valued operands. Controls cover omitted pad planes,
off-by-one powers, stale zeta/mu, imaginary truncation, missing support,
duplicate/out-of-range planes, zero-zeta acceptance, all seventeen residency
requirements, all twelve BASE requirements and each raw/first-round guard.
This is a constructor/gate/pad-polynomial test, **not** a new full sumcheck
oracle or native differential run. The previous cycle's complete synthetic
round tests remain separately scoped.

`validate.py` passes **51 source assertions, six source-mutation controls,
and 13 unchanged file pins**. Source and startup snapshots, code hashes,
commands and logs are retained. The source assertions guard specific seams;
they are not a Rust parser or a proof of implementation equivalence.
`initial-row-labels/` and the first command logs preserve a corrected initial
8B row-width label (16 changed to actual 13/13/14); cube sizes and the
all-eleven conclusion are unchanged. Final results add a nonresidue check.

Final experiment leaf: **0.442 s, 12,268 KiB RSS**, Intel Core Ultra 9 185H,
WSL2, Python 3.10, one thread/core 0, nice 19. Each leaf has 59-second CPU
and alarm, 60-second parent timeout, and 512 MiB address-space caps. Audit
leaf: 0.017 s / 17,848 KiB RSS. These clocks measure synthetic CPU execution.

```text
python3 experiments/public-pad-eligibility-20261020/run_bounded.py probe.py
python3 experiments/public-pad-eligibility-20261020/run_bounded.py validate.py
```

## Baseline, eliminated work, added costs and ceiling

No native work was eliminated here. The census selects which **previous**
source-count row matters for a native A/B: k=11, rather than arbitrary sparse
supports. At L=2^21 cube entries, the prior raw BASE phase1b model counted:

| Variant | Base products | Adds + subtracts | Logical shared operand reads |
|---|---:|---:|---:|
| Literal | 111,149,056 | 423,624,704 | 912 MiB |
| GL-only | 96,468,992 | 326,107,136 | 656 MiB |
| Prepared full BASE pair | 67,108,864 | 76,546,048 | 304 MiB |

GL-only removes 14,680,064 products, 97,517,568 adds/subtracts and 256 MiB
logical reads, with zero host preweights or added parameter bytes. The full
pair removes 44,040,192 products, 347,078,656 adds/subtracts and 608 MiB
logical reads, with **eleven fresh Fp2 preweights and up to 176 parameter
bytes per supported padded sumcheck**. Both preserve both-coordinate high/low
stores. Neither saves global/capacity bytes or barriers. Values are carried
from cycle 0099's pinned cost artifact, not a new timing measurement.

L=2^21 matches nominal R9 8B T128 FFN geometry, but does not establish its
GPU admission or execution. Source-call counts are not compiled instructions,
physical traffic or elapsed savings. Compiler elimination, registers/spills,
branch/code size, occupancy and host staging remain unknown. If f is the
unknown exclusive raw-derived phase fraction, even deleting it entirely
permits at most 1/(1-f) enclosing speedup; either adapter does less and may
add costs. No numeric end-to-end GPU rate follows.

Falsification: any broader eligibility, constructor drift, mismatch in refusal,
rounds/next challenges/receipt/verification, absent compiler savings or
enclosing regression. Do not change the mask schedule, public/private set,
final bindings, both endpoint stores, or subsequent extension-valued folds.

## Sources and next action

Eight LIVE primary records were appended (577 -> 585), with exact URLs,
date evidence, license inspection scope, available immutable commits and
access failures in `source-records.json`. New useful screens are the
[consumer Blackwell NTT report](https://github.com/pscamillo/icicle-blackwell-ntt),
[COBRA's 1998 primary paper](https://csaws.cs.technion.ac.il/~itai/Courses/Cache/bit.pdf)
and [Pico 3.0's September 30 pipeline announcement](https://blog.brevis.network/2026/09/30/pico-3-0-real-time-ethereum-proving-on-4-gpus-with-100-bit-provable-security/).
Their performance claims are not reproduced here. The inspected native NTT
already gathers bit-reversed input inside `k_ntt_p1`; no standalone reorder
pass was found at that seam. Pico's different field/PCS/helper reduction is a
protocol research lead, with extra sumchecks, final openings and privacy
review costs. Its four-GPU Ethereum result supplies no native 8B forecast.
API/history refreshes support the source log, not a paper-list speed claim.

Exact commit fetch was rate-limited (429); several primary code/license/history
pages returned Cache miss/Internal Error and the ZeroCheck PDF returned 403.
No bypass, dependency installation, external code execution or messages.

Next owner: shared-lock literal/GL-only/full-pair native A/B on supported
k=11 descriptors; ptxas registers/spills, actual eligibility incidence and
exclusive/enclosing clocks, masked-round/next-challenge/full-receipt parity,
fresh independent verification and strict GPU/refusal/CS/H-1/privacy gates.
Resolve the newer-profile/GZC port explicitly before assigning its costs.
Handoff: [review supplement](../../handoffs/20261020-public-pad-eligibility.md).

Next local: address-only sector census of the actual fused `k_ntt_p1` load
for n_src=n+q and compact/DIF paths, with independent indexing and row-stride,
padding and permutation negative controls. Count only public addresses, no
device job and no bandwidth forecast. Native phase/compiler evidence takes
priority over further source-level refinements. Fifteen ranked hypotheses
with costs, exactness, privacy/soundness and falsification are retained.

## Full-stack accounting

New completed independently verified full-stack **proofs/passes/positions:
0/0/0**. Actual model context/device: none. New witness, proof, serialization
and verification clocks; startup fraction; steady-state and total-workload
proved rates: **unmeasured**. No long prefill, repeated resident-model pass,
or decode ran. Synthetic shape T is not a processed context.

Carried non-DD CPU 8B T128/L32, one 16-thread pass, GPU off: total 478.737 s
= 0.267370 positions/s; prove_run 393.785 includes witness 98.348/load17.595;
seal84.824 overlaps phase accounting; receipt922,711,264 B; fresh verify
42.709+load13.681 s; recheck34.395+load10.739 s. Not rerun or reverified here.
Startup, steady slope and isolated serialization are unknown. DD T128
478.7 -> 474.9 s is a shared-box n=1 null result; R9 soundness acceptance
carries N-r9-a/b, DD privacy still owed. D33's narrow frozen R7 TinyLlama
T32 scope is not extended. Latest fidelity costs are owner projections for
new profiles, not performance or privacy acceptance.

Complete private 8B >=50 proved tokens/s on RTX 5090/another named high-end
GPU remains unachieved. Larger workloads remain allowed; longer attention
contexts can add quadratic work. No mask/opening reuse or privacy weakening.
Only research excluding runtime was written; no merge, production/Git/build/
GPU/install/receipt/calibration/gate/instruction/reviewer change. Saved reports
are not evidence of external message delivery.
