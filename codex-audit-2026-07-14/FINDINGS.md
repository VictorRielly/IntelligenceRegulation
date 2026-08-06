# Detailed findings

Severity means:

- **Critical:** invalidates a central security, privacy, or target-contract
  claim in the reviewed path.
- **High:** blocks a safe protocol/GPU milestone or materially overstates what
  is proved.
- **Medium:** must be corrected before exposing the implementation to
  untrusted proofs, but does not alone invalidate the local honest-path demo.

Line numbers refer to the snapshot in [SNAPSHOT.md](SNAPSHOT.md).

## C-01 — The optimized ARP rejection parameter does not establish negligible ZK

Commit `e6727e4` replaces the earlier rejection constant with a formula driven
by `ARP_REJ_T`, and the frozen value is now `1.5`
(`ring/ct_engine.rs:1343-1360`). Commit `92ca018` applies the corresponding
joint test to four coupled bundles. The comments explicitly identify the
discarded region as `Phi(-t)` but say it belongs to approximate-extraction
slack rather than soundness.

That interpretation is incompatible with the repository's own proof. Lemma
Q4.2b in `Q4_LEMMAS.md:143-173` states that the accepted distribution is only
within a `2^-t^2/2`-class defect of the center-independent Gaussian. Its proof
bounds the tail by:

```text
2 * exp(-t^2 / 2)
```

and obtains its approximately `2^-102.9` result at `t = 12`. At `t = 1.5`:

```text
one-sided normal tail Phi(-1.5)       ~= 0.0668
the lemma's stated two-sided bound    = 2*exp(-1.125) ~= 0.649
```

Neither quantity is negligible. For comparison, the same bound needs about
`t >= 13.4` to reach 128 bits. Joint rejection changes restart cost; it does
not make this clipping event disappear.

There is a second precondition gap. `derive_arp_params` sizes `sigma_arp` from
`1.3 * sqrt(n/2) * w_inf`, an honest expected/concentration-scale center, not
from a checked upper bound on the actual `||R b||`. Neither `arp_attempt` nor
`arp_attempt_joint` gates that actual center norm before applying the density
ratio formula. The proof therefore also lacks an executable guarantee that
the assumed `sigma = alpha ||center||` regime holds for every accepted
witness.

**Impact:** the legacy q46 range/ARP chain cannot be described as
statistical zero knowledge with a negligible defect at the frozen operating
point. `freeze-check` locks in the fast restart rate, not the missing security
bound.

**Required fix:** preferably remove ARP from the target path and finish the
exact range-lookup replacement. If ARP remains, derive `t` from an explicit
statistical-security target, enforce an actual center-norm bound, use an
audited discrete-Gaussian/rejection implementation, and rerun economics with
the secure parameter. At the repository's own `t = 12` class, the advertised
approximately 2.8 attempts is no longer the relevant model.

## C-02 — Multi-wave partial scalars expose private activation measurements

`split_claims_prover` computes and sends one partial constant term for each
wave touched by a linear claim (`ring/ct_engine.rs:1643-1672`). The verifier
checks that those values sum to the original public scalar
(`1677-1711`). The U-R layer sends these values for the nine randomized pin
claims and for the zeta families (`ring_matmul.rs:13777-13800` and
`14060-14103`). The design records this choice explicitly as “PARTIAL SCALARS
IN THE PROOF” (`PROGRESS_UR.md`, D-1).

The sum constraint proves sound composition, but it is not a privacy proof.
Before splitting, the verifier learns one total linear relation. After
splitting, it learns each deterministic partition contribution. In the many
waves holding the `Y/UP/Z` triples, a pin partial is a Fiat–Shamir-derived
linear functional of that wave's private `Y` coefficients; lookup mask and
blinder commitments live in other waves and do not add an independent pad to
that share. The ct-round's `g` material masks the opening protocol—it does not
hide the public scalar on the right-hand side of the claim.

At the measured `2^20` shape there are 670 waves. Nine pin copies therefore
expose roughly six thousand extra base-field measurements before considering
other reveal families. The repository tests whether altered shares are caught,
but contains no simulator, rank/leakage analysis, or recovery battery for the
honest share vector.

**Impact:** private intermediate activations are not shown to remain zero
knowledge in the multi-wave construction. This is a newly introduced
disclosure channel, independent of whether each individual ct-round is ZK.

**Required fix:** do not publish deterministic partition sums. Use random
additive shares whose pads cancel only in the aggregate and prove consistency
with committed pads, or aggregate the linear claim without exposing per-wave
right-hand sides. Specify a simulator for the complete multi-wave transcript
and add a rank/recovery battery that compares what is learnable from the total
claim with what is learnable from every wave share.

## C-03 — The proof-size report omits the ct-round proofs

`LayerCost` counts only the masked-descent bytes and `12` bytes per partial
scalar (`ring_matmul.rs:13050-13078, 14408-14418`). Each wave also constructs a
full `CtRoundProof`, verifies it immediately, and drops it
(`14120-14168`). Dropping is a useful memory optimization for the monolithic
harness. An actual non-interactive verifier must receive those proof objects;
streaming them to disk/network does not remove their wire bytes.

`CtRoundProof` contains, per ordinary commitment, at least:

- `z`: `n_r * D` signed response coefficients; and
- `w1`: `kappa * D` field coefficients.

At the rig's `n_r = 26`, `D = 128`, `kappa = 8`, a straightforward fixed-width
encoding gives the following two-array subtotal:

| Shape | Plain openings | `z` | `w1` | Subtotal |
|---|---:|---:|---:|---:|
| battery, 4,092 el | 209 data + 152 g = 361 | 9.17 MiB | 2.82 MiB | 11.99 MiB |
| measured `2^20` | 50,197 data + 38,050 g = 88,247 | 2,240.65 MiB | 689.43 MiB | **2,930.08 MiB** |

The `2^20` subtotal is about **2.86 GiB** and **11,720x** the 256 KiB target.
Even halving every coefficient to four bytes leaves approximately 1.43 GiB.
This still excludes `h`, claim masks, quadratic proof fields, public
commitments, masked descents, partials, framing, and the statement.

A linear extrapolation to one `512 x 11008` activation tensor is about 15.4
GiB for only these arrays; 32 such layers would be about 492 GiB. This is an
accounting projection, not a claim that the current machine can run that
shape, and it illustrates why an aggregation/compression proof is mandatory.

**Impact:** the printed `0.512 B/el` “masked transcript” is not proof size and
cannot support the 120–170 KiB model or 256 KiB contract. GPU acceleration
cannot change the number of transmitted responses.

**Required fix:** define the canonical proof first, serialize every component,
and measure the resulting file. More importantly, redesign the opening layer
so the proof is sublinear/aggregated across commitments and waves. A byte-level
budget must be an exit criterion before any full GPU backend.

## C-04 — The uncommitted U-S1 verifier is underconstrained

The current dirty U-S1 work is described as minimal pre-Phase-3 plumbing, and
it should remain labeled that way. It is not a sound independent proof format:

1. `us1_verify_bytes` parses both `spec_dg` and `commits_dg` from the proof
   bytes (`ring_matmul.rs:9623-9635`). It receives no separately trusted
   expected public statement or commitment list. A prover therefore selects
   both the proposition and the value used to derive `h0`.
2. `commits_dg` is a hash stand-in built by the prover from multiplicities and
   blinder values (`9548-9568`), not a commitment list accompanied by the
   ct-round openings that bind the proof to it.
3. Both descents call `masked_gkr_verify(..., false)` (`9640-9646`). With
   `pin = false`, `g_sum`, `open_g`, and `open_r` are not tied to committed
   masks (`ring/gkr_masked.rs:940-1050`).
4. The existing E3Z-N1 battery constructs a false lookup that **accepts** when
   this pin flag is false and rejects only when it is true
   (`ring_matmul.rs:8688-8757`). This is direct repository evidence that the
   omitted boundary is load-bearing.

The parser also accepts trailing bytes, accepts field coordinates without
checking canonical `< q` encodings, and uses independent large vector caps
rather than a total proof/resource budget.

The isolated U-S1 battery is green after rebuilding current source: honest,
free-h0, and stale-h0 legs behave as programmed. That confirms transcript
consistency for those particular honest-generated bytes; it does not address
the missing statement, commitments, or mask pins.

**Impact:** merging this tranche as “independent verifier/security boundary
closed” would create false assurance. An adversarial prover is not restricted
to bytes emitted by `us1_prove_bytes`.

**Required fix:** proceed directly to the real Phase-3 types. The verifier must
take an expected `PublicStatement` separately, parse canonical proof bytes,
recompute commitments/transcript seeds, verify every mask/blinder/data opening,
and reject any trailing/noncanonical/oversized data. Port E3Z-N1 to attack the
serialized API and require rejection.

## H-01 — Move semantics and a private nonce do not enforce freshness

The dirty change improves ergonomics by consuming `MaskSet` by value
(`ring/gkr_masked.rs:785-797`). It does not make repeated coefficients
unconstructible:

- `MaskSet::harness_clone` is still available in the release source
  (`gkr_masked.rs:197-213`);
- `ProverRng::from_test_seed` is a public deterministic constructor in the
  same shipped module (`ring/mod.rs:763-781`); and
- a caller can create two generators with the same seed or independently
  reconstruct the same mathematical mask without cloning the Rust object.

`session_nonce` is private prover state. It is neither included in a public
commitment nor absorbed into the transcript (`ring/mod.rs:732-788`). It can
label an object for debugging, but a verifier or session registry cannot use
it to detect reuse. In addition, buffering `/dev/urandom` in a 1 MiB
`BufReader` makes a generator unsafe to carry across `fork`: parent and child
can inherit the same already-buffered stream.

**Impact:** the normal OS-entropy CLI path is materially better than the prior
public-seed path, but the claimed “no reuse path” and “auditable freshness
handle” are not API invariants.

**Required fix:** place deterministic constructors and deep clones behind
`cfg(test)` or a non-production feature; make the production session object
non-cloneable and non-forkable; draw from the OS without a fork-duplicable
userspace buffer or reseed after fork. If uniqueness is a protocol property,
bind a public session nonce before commitments. If it is only internal
bookkeeping, remove the stronger security claim.

## H-02 — The exact range pilot is not part of Statement semantics

The lookup-based range direction is promising, but the public statement does
not currently describe it:

- the layer statement adds only the SiLU `Lookup` operation and `Hadamard`
  (`ring_matmul.rs:13397-13420`);
- the `RangeOnly` arm has no operation asserting anything about `X`;
- `range_dg` is bound only in a local lookup prehash
  (`13715-13731, 13851-13865`), not as a typed operation/table in the
  statement/model digest;
- manifest v2's `Lookup` validator hard-codes the canonical SiLU table and has
  no multiple-table vocabulary (`manifest.rs:865-883`); and
- the range tree looks up the affine code `x + 128`, while the statement's
  quantization metadata describes signed int8 `X`; the encoding transition is
  not represented as an operation.

The docs also acknowledge that data values are covered while commitment
padding is not.

**Impact:** a local monolithic verifier can follow the intended variables, but
an independent verifier cannot derive the exact range proposition from the
public statement. Model identity and transcript meaning are not portable.

**Required fix:** Statement v3 needs typed table instances, raw/affine encoding,
input/output quantization, domain, digest, padding rules, and an explicit
operation linking signed `X` to its `[0,256)` code. Include every table digest
in the model identity and test wrong table, wrong offset, and uncovered pad
attacks through serialized verification.

## H-03 — The implemented layer is not an FFN or transformer feedforward

The U-K8 statement contains Binary, Range, Lookup, and Hadamard operations
only (`ring_matmul.rs:10858-10880`). The U-R layer statement is smaller still:
Lookup when enabled plus Hadamard (`13397-13420`). Inputs `X` and `UP` are
generated inside the benchmark rather than supplied with a model artifact.

No proof in this path establishes:

- `gate = W_gate * X` and requantization;
- `up = W_up * X` and requantization;
- `down = W_down * (SiLU(gate) .* up)` and requantization;
- residual addition or layer-to-layer equality;
- RMSNorm, attention, RoPE/positional semantics, softmax, embeddings, or output
  projection; or
- identity of an 8B model's architecture and committed weights.

The repository has a 32-layer statement inventory containing those operation
names, but an inventory/validator is not a composed proof.

**Impact:** “FFN-INTEGRATED/CLOSED” currently means an activation subchain at
prototype granularity, not proof of one caller-supplied FFN layer, much less a
transformer feedforward.

**Required fix:** rename the milestone to “committed activation-chain rig.”
Make the next protocol exit one complete, caller-supplied quantized FFN layer
with all three matmuls, rescale/range edges, residual/output binding, and a
fresh-process proof. Only then compose layers and add the other transformer
operators.

## H-04 — There is still no repository-wide verified proof boundary

`ClaimManifest::digest()` remains public and unconditional
(`manifest.rs:159-255`). Structured and lattice binaries still call it
directly (`bin/structured_matrix.rs:3646` and
`bin/lattice_matmul.rs:3212,3865`). Selected ring rigs use validated Statement
v2; validation is not the sole way to obtain a transcript context.

Phase 3 remains a plan in `PROGRESS_US.md`: there are no canonical
`PublicStatement`, `ProverInput`, `Proof`, and `VerificationError` types, no
complete encoder/decoder, no verified setup import, no malformed-input fuzzing,
and no verifier that consumes only expected public input plus proof bytes.

**Impact:** GPU kernels do not yet have a stable protocol ABI. Optimizing now
risks hard-coding harness-local layouts and preserving unsafe parser/API
assumptions.

**Required fix:** finish Statement v3 repository-wide, disable bare manifest
digests outside migration tests, then implement and fuzz the canonical proof
boundary before defining a GPU host/device ABI.

## H-05 — Current economics remain incompatible with the target

The recorded `2^20` arm-A rates are 16.0 us/el commit, 578.7 us/el prove, and
187.4 us/el verify. They correspond to approximately:

```text
1,048,572 elements: 16.8 s commit, 606.8 s prove, 196.5 s verify
512*11008 layer:    90.2 s commit, 54.4 min prove, 17.6 min verify
32 such layers:                    29.0 h prove, 9.4 h verify
```

The latter rows are linear projections from the repository's measured rate,
not completed runs. They cover only the activation-chain rig and exclude
matmuls, witness inference, attention, layer composition, and serialization.

The 8.52-billion-coefficient statement inventory likewise reports only modeled
commit-stream rows (approximately 1,001 s single-threaded / 115 s at an
assumed 22-thread factor). No GPU kernel, transfer measurement, or p95 artifact
exists.

**Impact:** there is no evidence path from current measurements to <=5 s,
<=2 s verification, <=256 KiB, or prover work comparable to the feedforward
itself. The gap is architectural, not merely a missing parallel kernel.

**Required fix:** after the security and proof-size redesign, construct a full
operation-count and byte model from the actual proof artifact. Set CPU
go/no-go ceilings before a GPU port and report measured p50/p95 including
inference, commitments, transfers, hashing, aborts, and serialization.

## M-01 — Wave helper APIs are harness-safe, not verifier-safe

`plan_waves`, `split_claim_shares`, and quadratic localization use assertions
and unchecked commitment indices (`ring/ct_engine.rs:1560-1725`). Malformed
external statements can panic rather than return a typed error. In addition,
`split_claims_prover` computes a share scalar from `msg_coeffs` only even though
the generic `CtClaim` can carry Ajtai coefficients. The comments constrain
Ajtai-bearing claims to one wave, but the function does not add that opening's
contribution to the computed scalar; an Ajtai-only claim defaults to wave zero.

The current layer's split claims carry no Ajtai terms, so this is not the source
of its honest-path result.

**Required fix:** make the helpers return `Result`, bounds-check every index and
group, encode the “no Ajtai split” rule in a distinct type, and add an
Ajtai-bearing regression or reject such input explicitly.

## M-02 — Freeze gates certify constants, not the required invariants

LKP-9 freezes the `t = 1.5` restart formula, wave capacity, deterministic
partition, and range digest. Green freeze output therefore prevents accidental
drift but says nothing about negligible rejection distance, privacy of partial
shares, complete proof bytes, or Statement semantics. Documentation repeatedly
uses “closed” based on those green harness gates while retaining caveats that
the full computation and artifact do not exist.

**Required fix:** keep reproducibility freezes, but separate them from security
exits. Add explicit fail-closed gates for the statistical parameter, simulated
multi-wave privacy, serialized byte budget, adversarial parser, and complete
FFN statement. Do not mark a protocol milestone closed solely because its
performance constants are frozen.
