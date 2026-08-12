# Proving a Transformer Feed-Forward Pass: Plan of Attack

Target: prove one forward pass of a simplified transformer — multi-head
attention + FFN blocks, residual connections, no LayerNorm or other
extras to start — over committed weights and activations, as one
simultaneous batched proof, on either proof track (pairing zkMatrix or
lattice Pi2). This document formalizes the decomposition, assigns every
operation to a proof gadget with its cost class, defines the batching
architecture, sets milestones, and lists the honest risks.

## 1. The statement

Fix a quantized model: weights `W` and all intermediate activations are
integers with declared bit-widths and scale factors, and the forward
pass is defined exactly in fixed-point arithmetic (multiply, accumulate,
rescale-with-rounding, quantized nonlinearities). The provable statement
is:

> "The committed output Y is the result of running the *committed
> quantized model* on the committed input X, under the fixed-point
> semantics declared in the statement header."

Two consequences to accept up front. First, field arithmetic mod q is
exact, so the mod-q statement equals the integer statement only while
values never wrap — every accumulation must fit below q (Remark 2.1 of
the lattice report; same logic on the pairing side's 255-bit field).
Second, the proof says nothing about how close the quantized model is to
any float model; that is a model-quality question outside the proof.
Every published claim must say "quantized inference," not "inference."

## 2. Operation taxonomy: everything in one forward pass

Unrolling one block (input X in Z^{T x d}, T tokens, d model dim,
H heads, head dim d_h = d/H, FFN dim f):

```text
Q = X W_Q    K = X W_K    V = X W_V             (3 matmuls, T x d x d)
per head h:  S_h = Q_h K_h^T                     (H matmuls, T x d_h x T)
             P_h = softmax(S_h / sqrt(d_h))      (elementwise exp + row-normalize)
             O_h = P_h V_h                       (H matmuls, T x T x d_h)
O = concat(O_1..O_H) W_O                         (1 matmul, T x d x d)
X' = X + O                                       (residual add)
U = X' W_1 + b_1                                 (1 matmul, T x d x f, + bias)
A = act(U)                                       (elementwise, e.g. ReLU)
Y = A W_2 + b_2 + X'                             (1 matmul, T x f x d, + bias + residual)
```

Every operation falls into one of four classes, and each class has a
gadget with a known cost:

### Class 0 — free (verifier-side homomorphic algebra, no proof at all)

Additively homomorphic commitments make these literally free: the
verifier *computes* the output commitment from input commitments and
never needs a proof.

- Residual adds, bias adds: `com(X + O) = com(X) + com(O)` (blinds add).
- Public scalar scaling (the `1/sqrt(d_h)` factor, folded into the
  fixed-point scale): scale the commitment.
- Head split/concat under per-column (lattice) or per-block commitments:
  re-indexing the commitment list.
- Row/column sums (e.g. the softmax denominator vector `Z_i = sum_j
  E_ij` from a committed `E`): a homomorphic combination of column
  commitments.
- Equality of two matrices committed under the *same* key and bases:
  direct commitment comparison.

This is the corrected version of the "aggregations and equalities can be
rewritten as matmuls" intuition: they don't need to be matmuls — they are
cheaper than matmuls, they are free. The only equalities that are *not*
free are cross-key ones (Class 2).

### Class 1 — matmul claims (the machinery we have, measured)

All eight matmul shapes above are committed-x-committed products —
exactly zkMatrix-zk / lattice Pi2 (all-hidden). Weights can optionally be
public (lattice Pi1, cheaper) in deployments where the model is not
secret. Same-shape claims batch: the QKV/O projections across all L
layers share the `T x d x d` shape (Algorithm 6 / wave scheduling); all
`H*L` attention-score matmuls share `T x d_h x T`; and so on. Current
measured costs (optimized backends, this machine): ~0.5-2.4 s per claim
lattice, amortizing to ~0.4-6 s per claim pairing depending on batch
size, verification 5 ms (pairing, batched) to ~1 s (lattice).

### Class 2 — plumbing claims (cheap, sub-matmul, need building)

1. **Chaining / key consistency.** The output commitment of one claim
   must be usable as the input commitment of the next.
   - Pairing track: `C` lives under `c_bases`, the next layer wants it
     under `a_bases`/`b_bases`. Either share one base family across
     roles (must re-check the paper's footnote-7 disjointness rules
     per sub-proof before collapsing) or add a commitment-equality
     proof (one IPA-sized claim per boundary). This is the review
     notes' roadmap gate, unresolved by design so far.
   - Lattice track: all commitments share one key `(G1, G2)`, but Pi2
     wants the left operand committed *by rows* and the right *by
     columns*. Activations that appear in both roles (e.g. X feeds
     `X W_Q` as rows... and `Q` then feeds `Q K^T` as rows again, but
     `K` must be row-committed so `K^T` is column-committed) need
     either dual commitments (commit by rows *and* columns, ~2x commit
     cost) plus a **transpose-consistency gadget**: random `s, v`;
     derive `com(Y v)` homomorphically from column commitments and
     `com(Y^T s)` from row commitments; prove the two scalar
     projections `s^T (Y v) = v^T (Y^T s)` agree with a Sigma-protocol
     of the T_t/derived-key form. Cost O(T + d) per repetition —
     negligible next to a matmul claim.
2. **Rescaling with rounding.** Fixed-point requires `y = round(x /
   2^s)` after products. Witness the remainder: `x = 2^s y + r`,
   `0 <= r < 2^s`. The linear relation is Class 0 (homomorphic); what
   needs proving is the range of `r` (and of `y`) — Class 3 below. One
   auxiliary commitment per rescaled matrix.

### Class 3 — elementwise/bilinear claims (the new primitive family)

The insight that makes this tractable with the machinery we already
have: **Hadamard (elementwise) products, binary constraints, and range
checks all reduce to the same inner-product shape as the existing
product sub-proofs**, batched by random projection.

- **Hadamard gadget.** To prove committed `z = x o y` (elementwise):
  draw random `v`; the claim `<v o x, y> = <v, z>` catches any error
  w.p. 1 - 1/|S|. The left side is an inner product of two committed
  vectors where `v o x`'s commitment is *derivable*: on the lattice
  side, scale the second slot of `com(x)` elementwise by `v` — a
  commitment under the derived key `(G1, D_v G2)`, the same trick Pi2
  already uses for its scalar key `s^T G2`; on the pairing side, fold
  `v` into the IPA bases exactly as `y_L` folds into the projection
  bases today. Then the existing garbage-term / product sub-protocol
  proves the inner product. Cost per gadget: one product-claim of
  vector length = number of elements — the same shape and cost as one
  matmul claim's *product step*, i.e. much cheaper than a full matmul
  claim, and batchable across all positions and layers by extending
  the random projection.
- **Binary constraints** `b o b = b` (bits are 0/1): a Hadamard claim.
- **Range proof** via bit decomposition: `x = sum_i 2^i b_i` is Class 0
  (homomorphic) once the `b_i` are committed; each bit column needs one
  binary constraint; `w`-bit ranges cost `w` extra committed vectors
  plus `w` batched Hadamard claims. On the pairing side this is
  literally the Bulletproofs range-proof pattern, which our IPA already
  supports structurally.
- **ReLU**: `a = ReLU(u)` becomes: committed sign bit `b` in {0,1}
  (binary constraint), `a = b o u` (Hadamard), and `b` consistent with
  the sign of `u` — i.e. `b o u >= 0` and `(1-b) o u <= 0`, both range
  claims on already-committed quantities. Total: ~2 Hadamard + 1 range
  per activation matrix.
- **Softmax without division**: commit `E = exp_q(S)` (quantized exp),
  compute row sums `Z` homomorphically (Class 0), commit `P`, and prove
  `P o (Z broadcast) = E` — a Hadamard claim — plus ranges on `P`.
  Row-stochasticity `sum_j P_ij = 1` is then implied (or checked
  homomorphically). No division is ever proven; only products.
- **The one genuinely hard element: `exp_q` itself.** Proving
  `E_ij = exp_q(S_ij)` elementwise is a nonlinear table relation.
  Options, in order of preference:
  (a) **lookup argument** over the quantized (input, output) table —
  zkLLM's tlookup / LogUp on the SNARK side, recent lattice lookup
  techniques on the PQ side; the principled answer, but a new
  primitive for both of our from-scratch stacks;
  (b) **piecewise low-degree fixed-point approximation with
  range-proved segment selection** — buildable entirely from Class 3
  gadgets (segment indicator bits + Hadamard products + ranges), at
  the price that the *statement* becomes "softmax with this specific
  piecewise exp," which must be declared in the model spec (the
  review notes' warning: approximation changes the statement — that
  is acceptable if and only if the quantized spec is the ground
  truth);
  (c) milestone-0 placeholder: benchmark attention with the exp claim
  stubbed as an unproven hint, to size everything else first — never
  shippable, clearly flagged.

Asymptotics confirm the intuition: per layer, Class 1 work is
O(T d^2 + T^2 d) multiply-adds; Class 3 work is O(T d * w) committed
elements — an order of magnitude smaller for realistic shapes, so
nonlinearities should cost a fraction of the matmul proofs *if* the
gadget constants are kept sane. The bit-width factor `w` (~8-16) on
range-proved tensors is the main constant to watch.

**Status reconciliation (2026-07-14; U-K8 tranche, PROGRESS.md A-D3;
measurements in M4_LOOKUP_DESIGN.md Sections 7''/7''').** The lookup
route for nonlinearities — option (a) above, built for SiLU as the
activation pilot — is no longer paper: the MASKED COMMITTED lookup
has run inside a chain (range-proved X in, table-certified
Y = SiLU(X), downstream gate-o-up Hadamard, one validated Statement
v2) with measured marginals: prove +205.9 us/el 1T [NOISY-SHARED],
committed material +14.1 dce/el at the as-built instance size,
amortizing as 1/B to ~1e-4 dce/el at per-layer 5.6e6-el instances
[MODEL]. The integration is CLOSED at 1020-element row-block
granularity [H-03 rename 2026-07-15, audit 2026-07-14: "closed" = the
committed activation-chain rig — range/lookup/Hadamard over
benchmark-generated tensors; none of the FFN's three matmuls,
requantization, or residual binding is proven; see
RANGE_AGGREGATION_DESIGN.md Section 0 item 5], NOT at the
single-instance 512x11008 shape, and it
surfaced two as-built capacity walls: (i) the q31 ct-round's C2 wave
cap (~134 commitments per wave) blocks a single committed descent
near 2^17 elements — an instancing wall this section's taxonomy did
not anticipate; and (ii) the q46 ARP granularity (~896-bit units,
budget-capped rejection alpha, whole-round restart coupling). The
asymptotics paragraph above survives measurement with its warning
vindicated and inverted in emphasis: the elementwise LOOKUP is indeed
sub-dominant, but the Class-3 bit-width constant is not — the q46
range family is 96% of as-built chain prove time (582 dce/el of q46
commitments). A restart-rate pathology in that family was fixed
2026-07-13 (log M parameterized by alpha, e6727e4; joint Q4.2b
rejection over the round's 4 coupled units, 92ca018 — restart work
~17x down; post-fix wall-clock share awaits a quiesced pass, M4
Section 7'''). Forward plan for both walls:
RANGE_AGGREGATION_DESIGN.md (multi-wave C2-cap lift + the
range-lookup rung, replacing bit planes with the same lookup
machinery); its U-R tranche is open with S0 (multi-wave claim
splitting) landed — ledger PROGRESS_UR.md.

### Addition 2026-08-12 — the attention half now has an integer spec

This taxonomy's attention rows (softmax, normalization, RoPE,
residual, embedding) were written when no integer specification for
them existed — the gap TARGET_CONTRACT.md Section 1 declares. That
gap is now closed on paper: **docs/zkmatrix-poc/ATTENTION_INTEGER_
SPEC.md** (U-PERF lane PD, 2026-08-11) specifies each of them at the
frugal-lm 125M shapes against the calibration study's real ranges,
with 7B/8B rows derived alongside [MODEL], and
scripts/attention_spec_spike.py machine-checks it (18/18: 734 range
facts, 522 identities, determinism and swept-input audits).

Taxonomy consequences, stated here so this document is not read as
current on its own: softmax lands in Class 3 via the EXISTING
lookup family (range-reduced exp on a per-scale table, the
silu-int8-table-v2 family precedent) plus an exact row-max
subtraction (Class 2 range facts + a binary argmax selector);
BOTH normalizations — softmax's row-normalize and RMSNorm — are
floor-division RELATION facts (degree-3 zero-check with broadcast
divisor + two-sided remainder range facts), NOT reciprocal
evaluations, so no new gadget class is introduced; RoPE is a
public-table Class 0/1 rotation; GQA head sharing is a public map.
The honest limitation the spec carries forward: the division
relation gives row mass in a proven interval, not exact
row-stochasticity (measured [282, 512] against 2^9 at the spike's
shapes) — any downstream argument must consume the interval, not
assume a probability vector. Costs, risks and the build-round
obligation list are in the spec; nothing in it is built.

## 3. Batching architecture: one simultaneous proof

The whole forward pass becomes a claim DAG over one global commitment
set. Transcript discipline (this is where soundness lives):

1. Commit everything first: weights (once, reusable across all proofs),
   input, every intermediate activation, every auxiliary witness
   (remainders, bits, exp outputs). All commitments enter the statement
   hash.
2. Draw all compression/batching challenges after the statement hash is
   fixed (the same ordering rule as Algorithm 6's rho and Pi2's (s, v));
   one Fiat-Shamir transcript covers the whole DAG.
3. Prove per *operation class*, not per operation: one batched matmul
   family per shape (Alg. 6 on the pairing side; shared-shape wave
   scheduling and, for public-weight deployments, Pi1 rho-aggregation on
   the lattice side), one batched Hadamard/range family covering every
   elementwise claim in the network, plumbing claims batched likewise.
4. The verifier recomputes all Class-0 commitment algebra, checks the
   batched families, and checks the statement hash binds the model spec
   (quantization scales, architecture shape, exp table digest) — the
   spec is part of the statement, or proofs become transplantable
   between models.

Claim inventory per block (shapes for T=512, d=512, H=8, f=2048):
3+1 projection matmuls (512x512x512), 8+8 head matmuls
(512x64x512 / 512x512x64), 2 FFN matmuls (512x512x2048, 512x2048x512),
~3 rescale+range families, 1 ReLU family, 1 softmax family (exp lookup +
Hadamard + ranges), ~2 transpose-consistency claims. With measured
per-claim costs and batching across L layers, a 12-block model of this
size projects to minutes of proving on the current lattice backend —
dominated, as intended, by the matmuls.

## 4. Milestones

- **M0 — rectangular shapes + claim DAG.** Both backends currently
  assume square power-of-two matrices. Generalize to `m x k x n`
  (parameter/SRS-layout bookkeeping, no protocol changes), and define
  the statement format: commitment manifest + operation DAG + quantized
  model spec, backend-agnostic (the review's two-track strategy: the
  swap must stay a backend change).
- **M1 — chaining.** Pairing: decide shared-bases vs equality proofs
  (write the footnote-7 analysis before collapsing families). Lattice:
  dual-orientation commitments + transpose-consistency gadget. Exit
  criterion: two chained matmul claims verify against each other's
  commitments with no re-commitment by the verifier.
- **M2 — elementwise gadget family.** Hadamard, binary, range,
  rescale-with-rounding, batched across positions; negative tests per
  gadget. Exit criterion: range-proved rescale of a committed matmul
  output, batched, at <20% of the matmul claim's prover cost.
- **M3 — FFN block end-to-end.** X -> XW1+b -> ReLU -> W2+b -> residual,
  quantized, one proof, both tracks if M0-M2 held the backend-agnostic
  line. First headline measurement: FFN-block prover time vs its two
  matmul claims alone.
- **M4 — attention block.** Decide the exp route (lookup argument vs
  piecewise-with-ranges) *before* building; this is the phase's main
  research decision. Then softmax-as-Hadamard, head bookkeeping, full
  attention block end-to-end.
- **M5 — L-layer model, one proof.** Full DAG batching, streaming
  witnesses (memory!), performance report against the matmul-only
  floor, and the honest comparison table vs float inference.

## 5. Challenges and risks, ranked

1. **Quantization semantics discipline (highest, cross-cutting).** Every
   rescale point, scale factor, and accumulation bound must be part of
   the declared model spec, with q-headroom verified per layer
   (accumulations at f=2048, 16-bit operands fit q=2^61 with room, but
   *chained* growth without rescaling does not — rescale placement is a
   correctness requirement, not a tuning knob). Getting one range proof
   wrong silently voids soundness of the whole pass. Mitigation: a spec
   compiler that emits both the fixed-point reference implementation
   and the claim DAG from one source, plus differential tests against
   the reference.
2. **The exp/softmax primitive (highest single-item risk).** A real
   lookup argument is new machinery on both tracks; the
   piecewise-polynomial route stays inside our gadget family but
   changes the statement and needs careful error accounting in the
   quantized spec. Decide at M4 start; prototype both on paper first.
   zkLLM's zkAttn decomposition is the worked precedent to follow
   rather than reinvent.
3. **Witness and commitment volume.** Committing every intermediate
   activation plus w-bit decompositions multiplies committed data by
   ~(2 + w) per range-proved tensor. At T=d=512, one block's committed
   witnesses are tens of MB (lattice) — fine; a 48-layer model wants
   streaming commitment generation and the wave-scheduled prover
   (already built) applied DAG-wide. Memory, not time, is the likely
   first wall.
4. **Chaining decision on the pairing side.** Sharing base families is
   the elegant answer but touches the soundness argument (footnote-7
   disjointness per sub-proof); equality proofs are safe but add a
   claim per boundary. Budget analysis time for the former, fall back
   to the latter.
5. **Rectangular/multi-shape support.** Pure engineering but pervasive
   (params derivation, SRS layout, batching by shape class). Do it
   first (M0) so nothing downstream is built on square-only
   assumptions.
6. **Verifier cost on the lattice track.** The lattice verifier is
   ~linear; across a full model it multiplies. Batched-verification
   kernels (built) help; Route R (planned, Tier 2) is the real fix.
   For a many-verifier deployment the pairing track's 5 ms batched
   verification remains the asymmetric advantage.
7. **Transcript/DAG engineering.** Dozens of commitments and challenge
   draws with a strict ordering requirement; one misordered challenge
   is a soundness bug invisible to happy-path tests. Mitigation:
   transcript KATs (as done for the decoupling fix) plus adversarial
   reordering tests from day one.

## 6. Where the initial intuitions land

- *"Unroll into simultaneously provable operations"* — correct; the
  formalization is the claim DAG with class-wise batching under one
  transcript (Section 3).
- *"Aggregations and equalities rewritten as matmuls"* — better than
  that: residuals, biases, sums, scaling, concat/split are free
  homomorphic algebra (Class 0). The equalities that do need proofs
  (cross-key chaining, transpose consistency) are sub-matmul-cost
  Sigma-protocols, and the elementwise products that look like they
  need new machinery reduce to the *existing* product/inner-product
  gadgets under derived keys (Class 3).
- *"Nonlinearities provable with less complexity"* — right
  asymptotically (O(elements * bit-width) vs O(matmul)), with two
  caveats: the bit-width constant on range proofs, and exp/softmax,
  which is the one place a genuinely new primitive (lookup) or a
  declared statement change (piecewise exp) is unavoidable.
