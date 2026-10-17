# Public support descriptors — owner review handoff

Cycle 0038, run `20261012T192555Z-2488fec6`, 2026-10-12. Synthetic exactness and
cost candidate only; **no native speed result, honest witness, receipt or privacy
closure**. Main/Claude reviews and integrates. No production patch or merge.

[Evidence, limits and rankings](../experiments/support-descriptor-20261012/README.md).
Final pass 1.586442 s / 18,332 KiB RSS; one nice19 Core Ultra 9 thread,
seed2026101238, 59-second/512-MiB caps. 84 fixtures, 398,272 samples,
2,009 independent original-cube MLEs, 70 support-sensitive tail sums, 336 public
extension values and 21 controls. Initial failed symmetric-point negative is
retained, then corrected with distinct coordinate challenges. No candidate
mismatch found. [Unapplied, uncompiled Rust sketch](../experiments/support-descriptor-20261012/support.rs).

The public `B::supp` vectors can be represented by disjoint-coordinate threshold
axes, two current field endpoints and a completed-factor scalar. `at(index)`
uses integer predicates and field-value selection; `bind(Fp2)` uses one lerp
per relevant bit; `terminal()` yields the exact original MLE. Explicit cube
dimension, bind order and axis extents are part of the contract. All constructors
are derived from admitted Shape and domains, never receipt-provided descriptors.

Patch seam: read-only `ops/zkp-mvp/candidate/hashline/src/private_block/argument.rs`
Tab:68, B::supp:810, tile_rep:835, build_tables_at:338, total/run_slot:447,
verify terminal:613; pad.rs:48/132/335, shape.rs:257/883, witness.rs:211;
`candidate/zkp-core/src/sumcheck/grouped.rs`:99/149/175. Copies and pins live in
the experiment native/ and native-manifest.json. A typed public-support Tab
avoids calling the materializing constructor. Typed driver tables keep original
positions and an explicit cube size; empty dense placeholders are invalid.
Both Grouped and Closure readers, generic private total, diagnostics/finals and
public extensions must be adapted. GroupPoly has no row index: assemble exact
cur/dif in its round reader; keep descriptors immutable during parallel scans
and bind exactly once after reduction.

Preserve these native contracts:

- Head padding is interleaved inside each KV group. Use low slot bits, not
  `[head_slot < q_heads]`.
- Coarse Ht is tiled on LEADING coordinates and constant over all padded j;
  S support cannot substitute for it. Preserve `per_row=t_pad`.
- Extra row-lift support coordinates are LEADING zero selectors; lifted byte
  table VALUES repeat but their multiplicity SUPPORT does not. Q/Kv/S row-lift
  refusals stay. Ruling P-3 row lift is distinct from P3 private weights.
- `carries_pad_rule` and `pads(dom)` determine whether a table exists. Toy
  table/challenge/degree counts stay frozen; explicit descriptor length checks
  retain named refusals on prover and verifier. No new profile admitted here.
- Causal mask remains independent. Multiplying support and mask MLEs is the
  native polynomial; the MLE of the Boolean product differs off domain.
  LogUp still acts on pads. No whole-row or future-score skipping is authorized.
- Public terminals apply every `(1-e)` selector; extension degeneracy, CFS,
  per-site masks, RNG sequence, claims/openings/transcript and privacy are owed
  exactly as before. This changes public shape representation only.

At the pinned m125 T512/16-padded-head geometry the two simultaneous SZC support
tables are 128 MiB logical payload and 8,388,606 dense folds. Descriptor work is
four lerps plus constant field state/metadata and up to 16,777,212 integer
comparisons over the proposed two-support endpoint schedule. Common cur/dif and
sample arithmetic remain. More ragged shapes have more predicates. These are
counts, not native peaks or wall clocks. Sequential RS peak savings cannot be
added. Compiler/branch/dispatch/metadata costs may erase the gain.

Complete ceiling: `positions/(Ttotal-Caffected+Cnew)`, ideal upper bound
`positions/(Ttotal-Caffected)`. Accepted 8B and isolated support clocks do not
exist. The historical one-block GPU-assisted RS/SZC total of8.394s bounds
deleting BOTH whole slots on that diagnostic; support is only a subset.

First owner gate: verifier terminals, native dense descriptor comparisons and
named refusal/frozen bytes under all registered shapes. Then exact generic and
grouped driver samples, finals, extensions, inconsistent-witness refusals,
mask/RNG/transcript/receipt and device/privacy gates. Instrument support
construction/read/fold/verifier shares before complete independently verified
A/B under the shared heavy locks. No build/GPU job is queued by this lane.

Reject any MLE/index/profile/tile/extension/pad/host/future-score/mask/byte/privacy
mismatch, peak regression, or absence of enclosing gain after charging adapters.
Negative projective-WHIR evidence in the README cautions against adopting fold
counts as a full-proof win. Preserve the prior slower fusion and small-phase
negatives. Accepted complete private8B proofs/passes/tokens remain0.

Next local experiment: a heterogeneous public/dense-table driver that composes
separate causal and support readers through total, all round samples, final
ordering and public extensions against an independent original-cube oracle.
Deliberately inconsistent synthetic planes must retain their old claims.
