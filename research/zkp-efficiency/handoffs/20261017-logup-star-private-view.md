# LogUp* private-view boundary — research handoff, not integration

Run `20261017T202105Z-363d38a1`, cycle0067, 2026-10-17 UTC.
**No speedup or native protocol delivered. Do not integrate an unmasked port.**

Research source: `experiments/logup-star-private-pushforward-20261017/pushforward.rs`.
Interface: `pushforward(&[usize], active_prefix_len, &[Fp2], table_size)` returns
private weighted bucket sums. `candidate` is only a local C-ABI arithmetic
wrapper, returning both those sums and the corresponding table dot product.
There is no GKR, transcript, PCS or privacy layer in this prototype. The
source-pinned native field is included in `isolated.rs`; production is untouched.

Validation:405fixtures/23166Fp2 pushforward values/405virtual claims,14controls;
independent polynomial-convolution/count audit24014checks and3binding controls.
Main0.357s, final audit0.089s, one CPU thread, capped59s/512MiB. Source hashes,
synthetic fixtures, compiler command, environment and limits are in the bundle.

New negative: a hiding pushforward commitment alone is insufficient. One
active lookup exposes its value through the unmasked virtual claim after
division by a public equality weight.20extension-field controls recover the
synthetic secret. Same-histogram permutations also differ in the public value.
Fresh scalar marginal masking is only an illustration, not a ZK construction;
reused scalar masks expose differences. Ordered original-witness binding,
support and all original denominator refusals remain necessary. These are
counterexamples to a naive private adaptation, not attacks on native/upstream
accepted proofs. Native refusal ordering and RNG were not exercised.

Concrete owner seam: the `gpu-zerocheck` copy's
`hashline/src/private_block/protocol.rs` lookup/H-helper construction and H
commit, `argument.rs` helper constraints, and `shape.rs`/`layout.rs` H/M/PCS
claim-site accounting. Any future patch needs new versioned construction
review and joint-view analysis before native byte/profile gates. No old mask
row, H opening or challenge can simply be dropped or reused.

Actual8BT32 per-block U8H1514base rows/99221504B, totalH1758rows/115212288B,
83U8 columns/11714560queries. Query-value arrays are already uncommitted, so
the saving in an extra query-value commitment is exactly zero. Gross H data
is a candidate target, not proven net displacement. A256-entryFp2 pushforward
has4096logical bytes; current row lift makes it131072B before masks.
GKR/ordered A-affine link, fresh masks, terminal PCS, scratch, launches,
transfers and serialization must be charged. No new mask-site budget exists.

NewR5 CPU phase diagnostic171.578s (fresh cli3 verify not observed at capture):
whole H commit/open/U8/exp-act19.5s => direct free-deletion ceiling1.128224x
with all other work fixed. Not a whole-architecture/GPU/5090 ceiling. Prior
fractional-tree disclosure/zero-denominator negatives stay binding.

Next local gate: source-derived83-column batching, public padding and distinct
claim-point/mask-site census; differential tests before any protocol proposal.
Next owner gate: completed independently verified native workload with phase
clocks and startup/steady slope, preserving P1/P3 and current rulings. No
resource-heavy run, GPU test or merge requested/launched by this research lane.
