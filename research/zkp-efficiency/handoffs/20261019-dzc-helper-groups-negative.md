# Do not promote generic D helper grouping

Cycle 0081, `20261019T131854Z-168a653c`, 2026-10-19 UTC.

The 19-group native-field coefficient prototype is correct on the bounded
synthetic scope but **does not improve observed row timing**. It is an
unapplied research artifact. Main/Claude owns review and integration; no merge
or production change is requested by the measured result.

Patch location: `experiments/dzc-helper-groups-20261019/grouping.py`, used by
`run.py::emit_arm`, generates `kernels.rs::driven`. Four-pointer interface:
118 Fp2 raw values (59 low/high pairs), 129 Fp2 runtime parameters, 36 canonical
base-u64 parameters and five Fp2 output coefficients. Runtime pack 2,352 bytes.
Only public topology selects groups; runtime values never prune work.

Actual seam: pinned `ops/zkp-mvp/gpu-zerocheck/hashline/src/private_block/argument.rs`
SC_DZC through `zkp-core/src/sumcheck/rounds.rs` SumcheckRounds. Six source pins
are retained and unchanged. All original 59 tables/folds/finals remain.

Against the same use-driven graph with noinline scalar adapters: 884→19
calls and caller local subtraction 360→208 bytes, but **deepest static span
424→504 bytes**, code 33,543→145,739 bytes and requested logical row traffic
4,320→8,528 bytes. Eight alternating cache-resident synthetic row pairs give
medians 6.2083→6.5255 microseconds; seven pairs favor the baseline. Shared
single CPU, no full-D or enclosing proof measurement, no GPU claim.

Validation: six fixtures, two public scalar catalogs, N2/8/32, seed2026101981;
780 coefficients, 390 original captured-Rust grid/78 off-grid values,
18 messages, 354 original finals/six final relations, 36 zero bindings,
seven native-path controls and separate 1,465-check boundary/source/assembly
audit. Captured D/catalog still uses field/Shape/Layout substitutes; candidate
field source is unchanged native code. Main 7.216 seconds, compiler4.627;
one nice19 CPU0,59-second/512-MiB caps per experiment. No Cargo/install/GPU.

The remaining local question is code sharing, not more generic cuts of the
same size. Address-abstracted graph census: 19 groups, ten shapes, including
one six-instance and one five-instance family. A template adapter must charge
all public index/parameter maps, additional loads and call-chain frames, and
must preserve per-proof parameter identity. This census is not an implemented
or timed optimization. Reject any slot/alias/refusal/degree/RNG discrepancy or
enclosing regression. Do not infer GPU allocation from x86 stack allocation.

Before any native promotion: native admission/challenge/alpha/g_u8 gates,
extension/mask/PCS/original final order, seeded bytes and RNG draws, actual
fresh verification/tamper and joint-view privacy. No additional private
opening, reuse of masks or privacy weakening is authorized. Whole-prover GPU
D/A and completed resident-pass slopes remain higher priority than this seam.

The R6 CPU diagnostic's delete-all-D ceiling is 1.105058x, not a candidate/GPU
forecast. New completed target proofs/passes/positions0/0/0; target rates,
startup fraction and target phase clocks unmeasured. >=50 proved positions/s
for the complete private 8B stack remains unchanged and unachieved.
