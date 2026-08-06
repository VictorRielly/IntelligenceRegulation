# Detailed findings

Severity means:

- **Critical:** invalidates a central security or computation claim.
- **High:** blocks the stated target or a safe next integration phase.
- **Medium:** does not alone invalidate the prototype, but must be resolved
  before treating it as a production proof system or GPU specification.

## C-01 — Concrete lookup ZK is defeated by public, repeatable masks

The masking algebra assumes fresh secret random coefficients. The concrete
callers instead derive masks and blinders through `LkpTranscript::challenge_k`,
which is a deterministic SHA-256/XOF computation from its seed
(`sumcheck.rs:40-105`). The seeds used by the shipped paths are public or fixed:

- U-K5c seeds masks and blinders only with the public table digest
  (`ring_matmul.rs:7898-7903`).
- U-K8 hashes a fixed function argument, block number, and public label into
  `mask_seed`, then derives every mask and blinder from it
  (`ring_matmul.rs:9777-9786`). The CLI and batteries call the function with
  hard-coded seeds (`ring_matmul.rs:10511-10520,10557-10563,10587-10593`).
- Commitment randomness and the other prover coins use the non-cryptographic
  SplitMix64 helper (`ring/mod.rs:709-729`) from the same fixed seed family.

Anyone who knows the source and the statement can reproduce the masking
coefficients. A public known pad is not a one-time pad. The repository's own
E3Z-N3 battery proves that reuse/cancellation exposes the multiplicity
histogram difference (`ring_matmul.rs:8682-8778`).

The claimed freshness enforcement does not repair this. `MaskSet` stores only a
`Cell<bool>` inside one Rust object (`gkr_masked.rs:54-64,185-215`), and
`masked_gkr_prove` asserts that this particular object was not used
(`gkr_masked.rs:392-404`). Re-running `draw_masks` with the same seed constructs
identical coefficients in a new object with `used = false`. A process restart,
clone/reconstruction, or separate prover instance bypasses the marker. The
battery checks that one object becomes marked, but does not test reconstruction
from the same seed (`ring_matmul.rs:8780-8791`).

**Impact:** the implementation does not realize the uniform hidden-mask
hypothesis used by Q4.7–Q4.9. The “lookup subprotocol is HVZK” label cannot be
applied to produced transcripts. It also prevents a meaningful chain-wide ZK
claim.

**Required fix:** introduce a prover-only CSPRNG seeded from OS entropy; draw
all mask, blinder, commitment, abort-mask, and proof nonces from it. Make the
deterministic generator test-only. Consume mask objects by value, bind a unique
proof/session nonce, and add a regression that reconstructs two mask sets from
the same seed and demonstrates that the production API cannot emit both. The
original Libra construction explicitly relies on random mask coefficients;
see [REFERENCES.md](REFERENCES.md).

## C-02 — U-K8 verifier trusts the prover's lookup seed hash

The prover computes the intended value:

```text
ctx_lkp = H(table_digest, h0_link_b)
h0_lkp  = ct_h0(CRS, ctx_lkp, all q31 commitments)
alpha   = Transcript(h0_lkp).challenge()
```

at `ring_matmul.rs:10209-10219`. It then stores both `alpha` and `h0_lkp` in the
prover-side `lkp` tuple (`10235`).

The verifier recomputes `h0_link_v` and the link challenges
(`10382-10392`), but at `10399-10403` it takes `h0_lkp` from that tuple and
starts its transcript from the supplied value. It never recomputes
`ct_h0(CRS, H(table_digest,h0_link_v), commitments)` and never compares the two.

This is not cosmetic. The repository's E3-N1 attack battery already shows why
an alpha that is not bound to the multiplicity commitment lets a prover choose
the corrupt multiplicity column after learning alpha. Trusting a free
`h0_lkp` gives a malicious prover exactly that ordering freedom (and grinding
freedom), while the downstream wave can still prove consistency with the
post-alpha commitment.

Today the code hides this because prover and verifier are two halves of one
function and no proof decoder exists. That means the demo tests the honest
prover's variable flow, not an adversarial verifier boundary.

**Impact:** the U-K8 end-to-end ACCEPT/REJECT battery does not establish the
claimed lookup soundness for an externally supplied proof.

**Required fix:** do not serialize or trust `h0_lkp`. The verifier must derive
it exclusively from its expected statement, CRS, ordered commitments, and
table digest, then derive alpha from that value. Add the exact stale/free-h0
ACCEPT leg and recomputed-h0 REJECT leg at the U-K8 verifier API, not only in a
separate algebra harness.

## C-03 — Statement v2 validates inconsistent integer semantics

### C-03a — A range proof disables the fixed-point scale equation

For `x = 2^shift * y + r`, the validator checks fraction-bit propagation only
when `y` is *not* narrowed. If a `Range` or `Lookup` consumes `y`, lines
`manifest.rs:622-634` skip both the width and `frac_bits` relation. A range proof
shows magnitude; it does not change the scale represented by the integer.

The generated 32-layer inventory relies on this escape hatch. Examples:

- gate accumulator: `frac_bits=8`, shift 19, output `frac_bits=4`
  (`ring_matmul.rs:4554-4564`);
- down accumulator: `frac_bits=5`, shift 21, output `frac_bits=4`
  (`4593-4603`).

Under the validator's own non-narrowed rule, these require
`y.frac_bits = x.frac_bits - shift`; both are impossible. The statement passes
only because the range/lookup fact bypasses the scale check.

### C-03b — Signed widths include an unrepresentable positive endpoint

`QuantMeta::max_abs` returns `2^(bits-1)` for a signed value
(`manifest.rs:326-334`) and capacity checks accept equality. A signed `bits`
value represents `[-2^(bits-1), 2^(bits-1)-1]`; positive `2^(bits-1)` is not
representable.

Concrete consequences in the inventory:

- `4096 * (-128) * (-128) = 2^26`, which does not fit the positive side of a
  signed 27-bit accumulator even though the validator accepts it.
- `(-128) * (-128) = 16384`, which does not fit a signed 15-bit Hadamard result;
  the inventory declares that result as 15 bits (`ring_matmul.rs:4579-4585`).

### C-03c — The frozen lookup scale and digest are not validated

`Lookup` checks only `bits == 8` and `signed == true`; it accepts any
`frac_bits` (`manifest.rs:773-788`). Header validation checks only that the
table digest is nonzero (`493-498`), not that it equals the canonical table
required by the operation. Thus a structurally valid statement can assign
arbitrary scales to the raw table codes or name an unrelated nonzero table
digest.

**Impact:** Statement v2 can hash and “validate” a computation whose declared
fixed-point meaning is inconsistent with its integer equations. This leaves the
prior statement-integrity finding materially open.

**Required fix:** freeze one precise integer encoding. Enforce the rescale scale
equation regardless of magnitude narrowing, or replace `frac_bits` with an
explicit scale-exponent transition that matches the chosen quantizer. Use
asymmetric signed min/max bounds. Bind a typed `TableSpec` (digest, input/output
quantization, domain) and require exact metadata equality.

## H-01 — Row-block composition does not close the U-K8 exit

The original U-K8 exit requires “one FFN gate tensor end-to-end” and a real
committed FFN-shape tensor (`M4_LOOKUP_DESIGN.md:795-810`). The new code proves
independent 1,020-element subinstances. The full `512 x 11008` tensor did not
run; the live document says so (`M4_LOOKUP_DESIGN.md:822-826`).

Subinstancing can be a valid construction, but it changes every fixed cost:
each block has its own multiplicity vector, masks, blinders, descents, pins,
q31 wave, q46 rounds, and transcript. There is no pass-level aggregation proof.
For one 32-layer surrogate pass:

- activation elements: `32 * 512 * 11008 = 180,355,072`;
- row-block proofs: `32 * ceil(5,636,096 / 1,020) = 176,832`;
- measured lookup transcript alone: `37.5 B/element`, about **6.30 GiB**, before
  q31/q46 commitments, openings, range proofs, and serialization;
- the target budget is 256 KiB, a factor of about **25,800x smaller** than the
  lookup transcript alone;
- the live 10.7 ms/element chain rate extrapolates to about **1.93 million
  seconds (22.3 days) single-threaded** for only this activation/range/Hadamard
  chain; and
- the lookup marginal alone extrapolates to about **37,153 seconds (10.3
  hours)**, matching the live document's roughly 37 ks figure.

The document simultaneously reports 14.1 committed coefficients/element at the
as-built block size and says that fixed cost would amortize to `~1e-4` at a
5.6-million-element instance (`M4_LOOKUP_DESIGN.md:704-710`). That amortization
is unavailable while the C2 cap forces 1,020-element instances.

**Impact:** U-K8 demonstrates local algebraic composition, not target-scale
closure, the 256 KiB proof budget, or the 5-second goal.

**Required fix:** keep U-K8 status “built at row-block prototype scale; target
exit open.” Design and measure pass-level aggregation/wide rounds first. Count
canonical bytes for every proof component, not only masked lookup messages.

## H-02 — The “FFN-gate chain” is not an FFN feedforward proof

`ffn_chain_run` internally generates random `X` and `UP`
(`ring_matmul.rs:9543-9547`). It accepts no caller tensor, weights, model
manifest, or declared model output. Its statement contains only `X`, `X-bits`,
`Y`, `UP`, and `Z`, with Binary, Range, Lookup, and Hadamard operations
(`9906-9926`). There is no Matmul or Rescale operation in U-K8.

Consequently it does not prove:

- `gate = Wg X`;
- `up = Wu X`;
- either requantization;
- `out = Wd (SiLU(gate) o up)`;
- the connection between layers; or
- any 8B-model weight or architecture identity.

The full-shape M5 path still measures commitment streaming, not a matmul proof;
the target contract records the largest full matmul proof as `128x256x64` and
the full-shape item as commitment-only (`TARGET_CONTRACT.md:107-118`).

**Impact:** GPU work based on U-K8 would optimize one activation subchain, not
the requested feedforward proof.

**Required fix:** define a caller-facing witness/statement API and prove one
complete quantized FFN layer—including all three matmuls and rescale/range
edges—before multiplying by 32 layers or quoting an 8B feedforward latency.

## H-03 — Statement v2 is not the repository-wide verification boundary

The old unvalidated `ClaimManifest::digest()` remains public and unconditional
(`manifest.rs:159-255`). The structured and lattice chain paths continue to use
it directly (for example `structured_matrix.rs:3646` and
`lattice_matmul.rs:3212,3516,3865`). Statement v2 is used by selected ring demos
and the inventory, not by every prover/verifier.

Additional gaps:

- `model_digest` in U-K8 is only `H(tag, n_el, table_digest)`
  (`ring_matmul.rs:9904-9905`), not the architecture, quantization spec, and all
  weight commitments promised by `TARGET_CONTRACT.md:24-28`.
- The validator tracks read/written sets but does not enforce an acyclic,
  topologically ordered DAG. Cyclic producer graphs can validate.
- `Add` accepts an empty input vector (`manifest.rs:689-713`).
- The validator's own documentation says `LinkEqual` requires matching
  orientation, but the implementation checks only shape and quantization
  (`738-746`).
- No canonical statement/proof encoding or parser exists.

**Impact:** GPU kernels would have no single validated protocol contract to
implement, and “model-bound proof” remains a demo-local claim.

**Required fix:** make validated, typed Statement v3 the only way to obtain a
transcript context. Remove/restrict bare digest use, validate topology and
operation-specific invariants, derive model identity from an actual artifact,
and add canonical decoding with malformed-input tests.

## H-04 — U-K9 is promising, but interrupted and unintegrated

The clean commit `e8fa777` is reachable on an attached worktree branch. It
builds and passes all 42 tests. My same-machine measurements show real gains;
see [TEST_EVIDENCE.md](TEST_EVIDENCE.md).

It is nevertheless not a finished tranche:

- it forked before U-K8 and has never been tested with U-K8;
- the merge has an explicit `ring_matmul.rs` conflict;
- every stage checkbox in `PROGRESS_UK9.md` remains unchecked;
- the promised `U_K9_KERNEL_REPORT.md` does not exist;
- no `2^23` masked run or host/device measurement exists;
- the CLI remains capped at `2^22`; and
- its 32-line live continuation fails to compile with Rust E0061 because the
  changed in-place `fold_body` signature is not propagated to its wrapper.

The clean commit improves the unmasked, uncommitted lookup core. It does not
remove U-K8's q31 C2 subinstance cap or its q46 range/restart bottleneck.

**Required fix:** preserve clean `e8fa777`; quarantine the live residue; merge
on a dedicated integration branch; retain both U-K8 and U-K9 batteries; add
boundary/overflow tests; then measure the committed masked chain. Do not infer
GPU performance by multiplying assumed CPU and GPU factors.

## H-05 — The proof artifact and production security boundary do not exist

U-K8's prover and verifier share one function, local variables, witness-derived
objects, and hard-coded layouts. There is no standalone proof type, canonical
serialization, independent verifier input, malformed-proof handling, secure
setup import, CSPRNG, zeroization, or side-channel analysis. Rust verifier
helpers still use assertions/indexing suitable for a harness rather than an
untrusted parser.

**Impact:** proof size is not measured, verifier separation is not exercised,
and the current tests cannot establish security against an external prover.

**Required fix:** create explicit `ProverInput`, `PublicStatement`, and `Proof`
types; serialize and round-trip them; run verification in a fresh process that
receives only public input and bytes; fuzz all decoders; replace benchmark
randomness/setup; and obtain independent cryptographic review before any
“secure” label.

## M-01 — U-K9's custom arithmetic needs adversarial boundary coverage

U-K9 adds a custom special-form reduction, split `u64` accumulators, AVX2
dispatch, packed tables, and deferred reduction. Its differential battery is a
strong start, but it exercises random small tables (`2^8`–`2^10`) and the host's
AVX2 path. It does not cover:

- coefficient vectors dominated by `0`, `1`, `q-1`, and reduction boundaries;
- maximum product sums and the documented large-layer accumulator cap;
- a forced portable bulk-kernel path on non-AVX2/x86 hosts;
- sanitizer/Miri-style memory checks; or
- a large masked committed U-K8 instance after merge.

Several safety conditions are only `debug_assert!`, while overflow would wrap
in release mode. Add an explicit runtime size/bound gate and target the kernel
with property tests before translating it to GPU code.

## M-02 — Documentation and Git state are inconsistent

The live M4 document marks U-K8 closed at row-block granularity, while committed
`TARGET_CONTRACT.md:67-69,113-116` still says U-K8 is open/not integrated.
`PROGRESS.md` leaves A-D3 documentation reconciliation unchecked. Only M4 and
the ledger have live edits; the promised scale-plan updates are absent.

The checked-out U-K8 commit, both side-branch commits, and the live worktree
edits are not represented by the recorded remote-tracking branch. This is a
recoverability risk, not a cryptographic one.

**Required fix:** preserve all refs/diffs, correct the closure label, reconcile
one status table across the target contract and scale documents, and attach raw
benchmark logs/artifacts rather than only prose summaries.

