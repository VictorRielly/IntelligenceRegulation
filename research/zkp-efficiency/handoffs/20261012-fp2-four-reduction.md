# Owner review: four-reduction Fp2 arithmetic

Cycle0036 / `20261012T172555Z-e8207bdf`. Main/Claude reviews and integrates;
research did not patch production, compile native code, run a GPU or merge.

The tested canonical Goldilocks2 formula reduces `bd` and `ad` first, then
reduces `ac + 7·bd_reduced + acc0` and `bc + ad_reduced + acc1`.
Both arguments fit u128 under the pinned `p` and nonresidue7. Four reductions
replace five; multiplication count is unchanged. Products alone use the same
formula with zero accumulator and two fewer wide additions. Canonical output
matches the independent integer-modular reference. Two unreduced products do
not fit u128; do not remove the preliminary `bd`/`ad` reductions.

Interfaces/sketches in [the experiment](../experiments/fp2-fused-mac-20261012/README.md):
`Fp2::mul(self,r)->Fp2` or additive `Fp2::add_product(self,x,y)->Fp2`;
CUDA `f2_mul(a,b)` and `f2_add_product(acc,a,b)` using lo/hi u64 products and
carry addition. Rust product-only,weighted-only,combined and CUDA alternatives
are retained as unapplied patches with candidate source copies/pins. Canonical
precondition is inherited; prototypes reject violations for testing, while
the native sketch does not introduce a new runtime admission/refusal rule.

Actual seams: read-only `ops/zkp-mvp/sonnet-hardening/zkp-core/src/field.rs:158`,
`zkp-core/src/sumcheck/grouped.rs:110`, and
`hashline/src/gpu/kernels.cu:63`. NVRTC source explicitly avoids `__int128`;
the CUDA sketch preserves high bits of7·bd and both addition carries. Its MAC
is an unused additive helper until an owner-reviewed caller exists.

Validation:54,848 primitive MAC/product fixtures,matching two-u64 MAC emulations,
2,097 schoolbook product cases,256 ragged partitions,64 complete source-derived
SC_SZC fixtures/256 schedules,576 original-cube samples/2,304 candidate samples,
6,912 direct-MLE finals and19 controls. Final3.602309s/17,736KiB RSS,seed2026101236,
one pinned nice19 CPU thread with59s/512MiB caps. These are synthetic algebra,
not independently reviewed native proofs or throughput. Code and source hashes,
commands and the initial passing Rust-only source are retained.

Illustrative n23/ls3/padded/release census after compiled denominators: weighted
only removes0.604134% of counted scan/fold reduction calls; global product
replacement removes18.791733%, including weighted products. Do not add these
fractions. Variable/constant products remain; modular additions become wide
carry additions; no persistent scratch is added. LLVM may already simplify the
constant7 reduction and the changed dependency chain may regress performance.
No isolated affected-phase or accepted8B enclosing clocks exist; no numeric
end-to-end speed ceiling follows. `N/(T-Caffected+Cnew)` remains the applicable
workload expression, retaining witness,PCS,transfers,serialization and drain.

Required owner review: audit every canonical caller because Fp's tuple field is
public; inspect release assembly; retain independent native reference arithmetic,
all frozen receipts,mask/RNG/transcript/extension/refusal behavior and old/new
independent verification. Any mismatch or enclosing slowdown rejects the patch.
Use source-pinned CPU/device conformance before guarded complete-slot/block A/B.
Actual VRAM,register/occupancy/spills and memory clocks remain unknown. No new
privacy/soundness acceptance,profile,mask or private-opening reuse follows.

Recovered cycle0035's wide model passes its retained checks but removes only
3.016534% of counted reductions in this illustration while adding1.275B limb
adds and792B per-part logical scratch. It remains a cost-negative/unknown-speed
alternative, not a proposed win. All prior fusion/row-stepping/compiler/privacy
negative findings stay on record. Complete private8B accepted proofs/tokens0;
>=50/s unachieved. Next owner decision is whether native compiler/phase evidence
makes the global arithmetic candidate worth testing; no heavy job is queued.
