# Budget-adaptive tiled lookup prefix — research handoff

Cycle0107 / `20261020T151854Z-beab78ce`. Candidate for main/Claude review; no merge or native
patch. Evidence: [experiment](../experiments/lookup-tiled-prefix-20261020/README.md).

Selected R9 T128 top16 per-column model68.030->36.022MiB at unchanged
tree-node/fold counts and6.4–6.9% extra original leaf reads. Stream only the
nine oversized leaf-layer services for a32MiB destination cap. Fixed q1
over all uncached layers is dominated. Counts omit original private A/model,
other proof owners, new masking/CFS/PCS, backing and transfers; no native fit
or throughput established. All clocks/proved positions remain unmeasured/0.

Research implementation is `experiments/lookup-tiled-prefix-20261020/tiled.py`.
`consumer(factory, row_count, point, q, lambda, field, stats)` yields a complete
cubic row, accepts the next global challenge via `send`, and finally returns
the terminal and four original-MLE evaluations. Factory reopens the immutable
ordered source. Exactly q+1 full source scans; each early message is computed
with preceding challenges only. Materialize four residual planes after q
challenges, preserving independent MLE products and terminal provenance.
`model(..., fold_cap_bytes=...)` chooses minimum q per public layer, at most4;
`fold_cap_satisfied` is false for a clipped budget. Budget is array capacity,
not complete device memory. Cached children are copied, never consumed.

Potential Rust interface after protocol design:
```rust
// Prospective research interface, not implemented or compiled.
trait OrderedFractionSource<F> {
    fn len(&self) -> usize;
    fn scan(&self, emit: &mut dyn FnMut(F, F)) -> Result<(), Error>;
}
// sample_round(known_prefix) -> cubic message;
// bind_global_challenge(r), then materialize_residual at a public cut.
```
Connect only through a separately reviewed replacement for frozenR9
`protocol.rs::u8_denominator_inverses/helper_inverses_u8/write_h`,
`shape.rs::lookups_per_position/claim_sites`, `layout.rs::lookups_at`,
`argument.rs::helper_sum/SC_TAB`. Exact source pins in source-pins.json.
The native U8 inverse cache already exists; rediscovering it is not a speedup.

Validation: 2934 checks/225 tiny consumers/14 controls; independent240
cost schedules/1680 mutations/70 original-MLE cases and causal scan checks.
All9 frozen/source pins unchanged. Commands/seeds/hardware/logs retained.
Unmasked F65537 only; native Goldilocks Fp2/masks/transcript/refusals/receipts
are untested. Control source drift is detected by the original oracle;
the prototype supplies no cryptographic source authentication.

Every root/intermediate remains private. Preserve one committed global
histogram,83 ordered U8 links atT128 (85 atcountedT512), every original
denominator refusal and exact multiplicity. Root equality alone does not bind
sites. A reviewed private GKR, masked terminal linkage to original A, actual
claim/PCS-site accounting, one-opening composition, whole-run soundness and
joint-view privacy are prerequisites. No public roots, guessed challenges,
mask/opening reuse or per-challenge inverse reuse. Preserve R9N-r9-a/b and
D32/D33/D34/D35; latest LOW fidelity proposal is outside these counts.

Owner validation before integration: actual capacity and complete phase
clocks; native original-MLE/round/transcript/refusal parity, independently
verified full receipts and current privacy gates under shared locks. Reject
if source storage/reloads or new proof owners erase the capacity benefit,
the device was not capacity-limited, any binding fails or total workload
regresses. No numeric end-to-end ceiling without exclusive fraction f;
even free affected-work deletion is bounded by1/(1-f).

Next local: port this consumer to exact native Goldilocks Fp2 arithmetic
with a synthetic ordered U8 reader using the same per-attempt denominator
cache/refusal rules. Differentially check every original helper term, all
sample rows and terminal MLEs, including zero denominators at zero multiplicity.
Keep source arrays immutable; never cache inverse results across challenges.

Next owner: complete GPU phase/capacity clocks and verified fixed-context
resident1/2/4/8 workloads, DD context scaling and all-eleven FZC compiler A/B
under shared locks. Count only independently verified complete receipts and
retain fresh masks. Main/Claude reviews any integration; no merge here.

