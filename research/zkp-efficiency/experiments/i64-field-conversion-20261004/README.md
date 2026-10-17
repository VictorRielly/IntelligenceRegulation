# Exact signed-i64 to canonical Goldilocks — cycle0021

Run `20261004T030146Z-711aedad`, checkpoint 2026-10-04T03:16:06.153383+00:00. Research-only CPU oracle and read-only disassembly. No candidate compilation, native proof, GPU, real private payload or measured proving improvement.

The A fill in `ops/zkp-mvp/candidate/hashline/src/private_block/protocol.rs:801` calls `Fp::from_i64` for every supplied witness coordinate. The canonical implementation is `zkp-core/src/field.rs:32`; hashline's field module reexports it. Source pins/snapshots are retained. The previous A-row count gives 88,918,016 conversions per synthetic m125 block; negative-value frequency is unknown and must not be exposed for a real private witness.

The existing source handles negative i64 via an i128 magnitude, modulo p and `Fp::new`. Since `abs(i64)<=2^63<p`, those normalization steps are mathematically redundant **in this typed domain**. Two independently written candidates use direct magnitude subtraction and signed-word correction. Review sketch:

```rust
let sign_mask = (v >> 63) as u64;
Fp((v as u64).wrapping_sub(sign_mask & 0xFFFF_FFFF))
```

For a nonnegative v, the raw word is already <p. For negative v, raw=2^64+v and raw-(2^32-1)=p+v lies in [p-2^63,p-1], so the result is canonical even at i64MIN. No signed negation, unsafe reinterpretation, precision change, new native refusal or randomness operation is required. Do not extend this identity to u64/i128/u128, `Fp::new`, random mask draws or challenge reduction.

Result: 139,880 scalar values, including all65,536 signed-i16 values,616 power/boundary values,65,536 full-i64 random values and8,192 values near extrema. Baseline, two candidates and an independent decoded-ELF model equal Euclidean quotient/remainder. Canonical bytes use both struct packing and independent repeated base256 extraction; base Fp2 embeddings have zero imaginary component. All60 scalar-Python vector models (6,800 words, widths1/2/4/8/16 with odd/empty tails),25 representative row copies (3,208 words) and20 controls pass. Supplied dirty internal padded words are copied unchanged; only public row tails zeroed. This is no native layout/full-block test.

CPU elapsed 2.257907s, peakRSS 22616KiB, Python3.10.12, Intel(R) Core(TM) Ultra 9 185H, one low-priority thread pinned toCPU0; estimated64MiB, cap512MiB,59s alarm. Command/log/result/source hashes retained. Initial run reached the final disassembly assertion and failed because its count omitted the witness load:10 total instructions,9 arithmetic. Original script/log/exit1 retained under `initial-loop-count-failure/`; only this assertion/count metadata changed before the passing run. No failing field comparison was hidden.

## Decisive negative and provenance limit

The inspected **current** ELF at the historical binary path has SHA256 `2c617ae5203c2db3b785ee56da364ad73407b2c8012e646ea0b2fdc876460015`; the old timing report expects `74abdad3a53e2010a5281329c2d985b8ee8676d75b3f68b9083e3840fb762337`. They differ. Do not attach this ELF's assembly to the old performance clock or claim a fully reconstructed source-to-binary identity. No executable was run/copied/rebuilt. The corrected disassembly metadata retains this mismatch; initial metadata is preserved separately.

In the apparent A conversion loop0x525830..0x525855, the magnitude/modulo source already lowers to word additions, a compare/conditional move and a sign mask. **There is no integer division or helper call to eliminate.** Its decoded arithmetic is independently checked against the modulo oracle, with both comparison choices exercised; the second constant never affects a negative i64. The new candidate could remove redundant compare/selection/normalization operations, but candidate native instruction count, vectorization and time are unknown. This demotes the original expensive-modulo hypothesis.

The adjacent allocation region0x525703..0x525770 contains malloc plus memset and the final zero store for A length>1. This narrows the prior zero-fill/compiler question for this current ELF, without measuring executions, pages, actual traffic, or the timed historical binary. Keep zero-store assembly and conversion as separate owner checks.

## Work removed, added costs and ceiling

A-only conversion changes no witness reads, A writes/capacity, histograms, fresh masks/pads, encoding, hashing, transfers or proof bytes. Source arithmetic becomes simpler; no removed division may be claimed. New sign-mask operations, compiler register/vectorization choices and a shared-field regression review are costs. Prefer a local A-loop prototype before changing all shared conversions.

The same historical synthetic12-block125M T512, onecold shared-host RTX4070Laptop8188MiB diagnostic has408.609226s enclosing wall,318.22s prover including witness/segment serialization,12.15s in-process verification,484107456B; independent verification false. Its A allocation+plane-fill parent totals86.691s (21.216% wall). Even deleting that **entire** parent at zero cost leaves321.918226s, arithmetic1.590466 positions/s. This bounds an A-only prototype optimistically, not conversion savings or countable private8B throughput. Trained8B ceiling is N/(T-C_old+C_new); phase terms are unmeasured. A shared field change outside A would require separate phase attribution.

Falsify on any canonical value/byte, native refusal/RNG/transcript/proof-byte mismatch; existing native compiler already producing the short form; more expensive vectorization/register behavior; or C_new>=C_old/enclosing time unchanged. Do not expose secret sign histograms. This oracle is not a privacy/soundness acceptance, nor an Fp2/PCS implementation change.

Full-stack accounting this cycle: CPU only,0 accepted8B passes/0countable tokens, contextnull. Steady-state/total rates,startup fraction,witness/proof/serialization/independent-verification,latency/lag/drain allnull. No long prefill,resident pass or decode proof. Larger workloads are allowed; attention can grow quadratically; no masks/openings reused.50/s unachieved.

LIVE source records: packed-sumcheck2025/719 with Sep14 2026revision, older combined2025/1117, EPFL compatibility/security/history and Plonky3 dated0.8.0release/changelog. See source-records.json/search-log.md for verified dates,exactURLs,license limits,full commit and access failures. No author speed reproduced. Main/Claude owns any promotion; researcher does not merge.

Next owner action: matched-source/binary assembly plus split allocation/conversion/copy clocks, then guarded native A/B and archived/fresh proof-byte/refusal gates. Next local cycle: exact signed-byte decomposition of int16 FFN-down witness dot products, both native weight orientations, i32 partial/i64 recombination bounds, signed requantization and first-refusal order. That targets recurring witness work instead of assuming conversion dominates.
