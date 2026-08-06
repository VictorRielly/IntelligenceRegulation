# Prioritized findings

Severity meanings:

- **Critical** — blocks the claimed secure/zero-knowledge computation.
- **High** — blocks a credible pre-GPU milestone or latency conclusion.
- **Medium** — material engineering, review, or claim-discipline debt.

## What improved

Before the open findings, two corrections deserve explicit credit.

1. **R1 is now a real committed implementation change.** The engine masks all
   three quadratic claim families; the tests keep the old leak and bad-order
   attacks alive and verify that the new order rejects them. This resolves the
   prior audit's R1 implementation-status objection at prototype level.
2. **E2 now rejects the actual composed-Hadamard defect.** The link rows read
   slot constants and randomly pin every remaining CRT coordinate. The battery
   demonstrates that constant-only rows accept malicious junk and the shipped
   zeta rows reject it.

These are meaningful advances. They do not by themselves complete a secure
transformer statement or production implementation.

## Critical

### C-01 — The implemented lookup transcript is not zero knowledge

This is not a speculative concern; the repository states and demonstrates it.

- `M4_LOOKUP_DESIGN.md` lines 369-400 inventory the unmasked round
  polynomials, boundaries, roots, and final MLE values as leaks and instruct
  that lookup-bearing proofs be labeled non-ZK.
- `M4_LOOKUP_ZK_DESIGN.md` lines 3-10 say the masking work is a design/spike
  with **no engine code**.
- The same document, lines 120-130, says one unmasked table descent reveals
  the complete activation multiplicity histogram.
- `python3 scripts/logup_zk_mask_spike.py` reproduces exact recovery of the toy
  histogram from one unmasked transcript.
- The Rust modules implement the unmasked sumcheck/GKR/E4 path. U-K5a through
  U-K5e in the design document remain unimplemented.

Impact: an activation proof built from the current Rust path reveals private
activation-distribution information. GPU acceleration would make a known
non-ZK protocol faster; it would not move the product toward its security
goal.

Required fix: implement U-K5a-e, not just the masking equations. At minimum:

- pre-alpha commitments to every round mask and blinder;
- masked sumcheck and masked GKR boundary logic;
- aggregate-only leaf pins so `v^X`, `v^Y`, and especially `v^M` are not sent;
- engine-scale histogram-recovery failure test;
- mask-reuse rejection across passes;
- every existing E3/E4 ordering regression rerun under masking;
- a reviewed simulator/rank argument at production shapes.

The design is promising, but its own general-shape rank lemmas remain listed
as obligations. The cited Libra construction supports the masking direction;
it does not automatically prove this custom Papini-Haböck adaptation.

### C-02 — The repository still does not prove the intended integer/model statement

The earlier exactness and statement findings remain open:

- `ring_matmul::chain_demo` still prints that q31 binary claims are modular and
  their non-wrap side condition needs a q46-class or exact strategy
  (`ring_matmul.rs` lines 3626-3631 and 3657-3659).
- `M3_REPORT.md` lines 225-231 still says input and model-weight ranges are
  declared/asserted rather than proven against their commitments.
- `manifest.rs` hashes caller-created entries and operations, but has no
  validator for referenced IDs, compatible shapes/orientations, complete DAG
  coverage, quantization metadata, table semantics, or model identity.
- E2 is implemented as generic machinery, but the actual chain demo still has
  a standalone H3 layer rather than a range -> lookup -> `gate o up` chain.

Impact: even if each local proof verifies, the verifier still does not establish
“this exact committed 8B quantized model evaluated this input under these exact
integer semantics.” Modular wraparound, omitted operations, or caller-created
manifest inconsistencies remain outside the proven statement.

Required fix: build a versioned validated statement and a generic verifier,
prove every input/weight/intermediate bound, and run a malicious wraparound
battery. This is a protocol gate, not a GPU optimization task.

## High

### H-01 — “U-K8 built and measured” does not match U-K8's own exit criteria

The design's original exit criteria are clear:

- U-K6 requires a real committed FFN-shape tensor, the slot-packed E1-composed
  variant, and measured verifier cost (`M4_LOOKUP_DESIGN.md` lines 643-650).
- U-K8 requires one FFN gate tensor through upstream range proof, lookup,
  downstream `gate o up`, and reconciled marginal costs (lines 656-661).

What exists is narrower:

- U-K6 is an in-process `N=256` dense-packed test (`ring_matmul.rs` lines
  6509-6650). It does commit X/Y/m and exercise nine E4 claims, which is useful,
  but it is not FFN shape and has no slot-packed E4 variant.
- `lookup-bench` defaults to `N=2^18`, constructs ordinary vectors, directly
  grounds MLEs, and times one E4 coordinate weight stream (`ring_matmul.rs`
  lines 6913-6987).
- The benchmark does **not** commit X/Y/m, build or verify the nine E4
  CtClaims, apply U-K5 masking, prove upstream int8 range, feed the result to
  a downstream Hadamard, or execute an FFN.

Nevertheless `LLM_SCALE_ESTIMATE.md` line 63 labels U-K1..K8 “BUILT +
MEASURED,” and the U-K8 commit message calls this the measured lookup engine.

Required fix: call the current artifact an “unmasked lookup-core microbenchmark”
and reopen U-K8 until its original integration test passes. Track core algebra,
E4 landing, masked lookup, and FFN integration as four separate statuses.

### H-02 — The CPU/GPU performance ladder mixes unrelated and inconsistent factors

There are three distinct problems.

#### The lookup's 22-thread row is not measured

`lookup-bench` is explicitly single-threaded and contains no Rayon execution.
It takes the **8.74x scaling measured for column commitments** in M5 and divides
the unrelated scalar GKR time by it (`ring_matmul.rs` lines 6993-6998).

The reproduced measurements are:

| lookup size | measured prover core | measured CPU use | printed 22T row |
|---|---:|---:|---:|
| `2^18` | 2.82 s | one core | 221 s/pass via imported 8.74x |
| `2^20` | 11.64 s | one core | 229 s/pass via imported 8.74x |

Only the single-thread measurements are real. The 22-thread lookup row is an
assumption until the lookup code itself is parallelized and measured.

#### “GPU 20x” uses two different baselines

- M5 computes GPU commitment time as `bill_22t / 20` (`ring_matmul.rs` lines
  7598-7601), so the factor is 20x over the measured 22-thread CPU result.
- Lookup computes GPU time as `pass_1t / 20` (lines 6993-6998), so the same
  label is 20x over one thread.

Those definitions differ by 8.74x. Under a single convention:

- if GPU is 20x faster than 22T, lookup is about 11-12 seconds/pass, not
  97-100 seconds;
- if GPU is 20x faster than 1T, commitment is about 55-78 seconds/pass, not
  6.3-8.9 seconds.

Neither generic convention is decision-grade because commitment NTTs, K-field
tree arithmetic, hashing, and proof assembly have different GPU speedups.

#### The pass inventory is still uncertain by 1.4x

`M5_LITE_REPORT.md` lines 239-242 carries two pass-level committed-element
counts, 9.4e9 and 1.33e10. That uncertainty alone is larger than many proposed
optimization wins.

Required fix: define one timing baseline and produce separate measured rows for
commitment, ring combinations, masked lookup, E4, hashing, RNG, transfer, and
proof materialization. Generate the pass inventory from the actual statement
DAG instead of manually maintaining two models.

### H-03 — The lookup implementation has not demonstrated FFN-instance memory viability

The code is allocation-heavy and retains whole trees:

- `KElem` is `Vec<u64>` rather than an inline fixed-size value
  (`kfield.rs` line 38).
- `build_tree` retains every P and Q layer (`gkr.rs` lines 66-87).
- Each descent constructs `eq`, `p0`, `p1`, `q0`, and `q1` tables and repeatedly
  folds newly allocated vectors (`gkr.rs` lines 184-215; `sumcheck.rs` lines
  184-204).
- The frozen FFN instance is padded to `2^23` leaves, but the CLI permits at
  most `2^22` (`ring_matmul.rs` line 5335).

The reproduced `2^20` run consumed **1,565,804 KiB maximum RSS**. A simple
linear extrapolation to `2^23` is roughly 12 GiB before GPU mirrors, masked
U-K5 buffers, proof serialization, or concurrent instances. This is not proof
that `2^23` must fail, but it is strong evidence that the current representation
has almost no headroom on the documented 15 GB machine and cannot be copied as
is to an 8 GB-class GPU.

M5's 94-95 MB result applies to streamed commitment generation, not the GKR
lookup data structures.

Required fix: use inline/SoA field elements, preallocated arenas, layer-wise
streaming or recomputation, and an explicit host/device memory schedule. Run
the actual `2^23` masked instance and record peak host and device memory before
claiming FFN-scale lookup support.

### H-04 — M5 measures commitments, not an FFN proof or even a valid matmul

`m5-bench` independently generates random A, B, and C columns, commits and
hashes them, then drops them (`ring_matmul.rs` lines 7323-7359 and 7417-7431).
It never computes `C=A B`, never constructs a full CE proof at the FFN shape,
and never verifies one. The wide claim-layer section times commitment volume
only.

The report is comparatively honest about this at lines 243-247: full CE rounds
remain measured only at `128x256x64`. The misleading phrases are “end-to-end”
and “full FFN-shape” when read as proof claims. What is end-to-end is the
**column commitment stream**, not proof generation.

Required fix: label it “full-shape commitment-stream benchmark.” Add separate
benchmarks for:

1. a valid FFN-shape matmul witness;
2. all CE rounds and R1 pads;
3. proof encoding and verification;
4. a complete gate/up/SiLU/Hadamard/down FFN.

### H-05 — The target is still a 7B/512 surrogate, not a specified 8B transformer

The active measurements use `512x4096x11008`, 32 layers, and are consistently
described as a 7B/512-token reference. There is no imported 8B model, model
digest, execution trace, or exact target contract. Attention, softmax, RoPE,
RMSNorm/layer norm, residual-scale semantics, and a multi-layer generic verifier
remain absent.

Required fix: freeze the exact model and benchmark boundary before GPU work:
model/version, parameter count, token mode, sequence length, quantization,
private/public fields, preprocessing, included inference time, hardware, proof
bytes, verifier time, and p95 target. A five-second claim is meaningless until
those are fixed.

### H-06 — Production implementation security is still absent

The Route R implementation still uses SplitMix64 for prover secrets and `f64`
Gaussian/rejection sampling with secret-dependent control flow (`ring/mod.rs`
lines 708-887). There is no zeroization, canonical proof parser, allocation
limits, fuzzing, or panic-free untrusted verifier API. `panic = "abort"` remains
the release policy.

The new lookup structs add more variable-length `Vec` values with no canonical
length checks. This is acceptable for an internal algebra prototype, not for
real private model activations.

Required fix: keep deterministic RNG behind tests, add an OS-seeded CSPRNG and
reviewed sampler, define canonical bounded encodings, validate all lengths and
field elements, return structured errors, and fuzz the verifier boundary.

### H-07 — Lookup soundness numbers exceed the concrete hash security ceiling

The documents quote field-statistical terms near `2^-486` and a final psi term
of `2^-279`, while all Fiat-Shamir state and XOF keys are SHA-256 digests. In a
random-oracle/PRG treatment, the algebraic terms are useful, but concrete
security must also be capped by the hash/Fiat-Shamir security and by the chosen
classical or quantum threat model. The current tables present the field terms
as if they were the complete concrete bound.

This does not make the intended 128-bit classical target fail. It means the
published quantitative claim should be `min(algebraic error, hash/FS bound,
commitment assumptions, parameter bound)` and should account for grinding and
multi-theorem use. Under quantum search, a 256-bit hash does not supply 256-bit
preimage security.

## Medium

### M-01 — Status documents have drifted again

Examples:

- `M4_LOOKUP_DESIGN.md` lines 3-5 still says “no engine code.”
- `M4_ACTIVATION_DESIGN.md` line 443 still calls R1 an inherited obligation,
  although R1 is built.
- `M5_LITE_REPORT.md` lines 248-251 says E3/E4 are pending, while the unmasked
  versions landed later.
- `LLM_SCALE_ESTIMATE.md` calls U-K8 built/measured despite its unmet exit.
- `ring_matmul usage()` omits the `lookup-bench` command it accepts.

Recommendation: maintain one generated status ledger with distinct columns
for design, implemented, integrated, ZK, measured-1T, measured-parallel, and
modeled. Make stale status a CI failure.

### M-02 — Rust behavioral coverage is still outside `cargo test`

`cargo test --all-targets` compiles successfully but runs zero Rust tests in
every target. Important coverage remains inside a 7,600-line binary self-test,
and the ZK masking spike is not part of the 42-test suite. This weakens test
selection, property testing, fuzzing, and GPU differential testing.

Recommendation: create a library crate, move semantic tests to `#[test]`, add
property tests for field/ring boundaries, and retain CLI tests only for slow
integration/benchmark cases.

### M-03 — Formatting, lint, packaging, and CI remain unfinished

- `cargo fmt -- --check` fails across a large portion of the Rust tree.
- Clippy completes but reports extensive warnings; `ring_matmul` reports 99 in
  the all-target run.
- There is no CI, root quick-start, license, fuzz target, or release checklist.

These are not cryptographic breaks, but they increase review friction exactly
when a second backend is about to multiply the code paths.

### M-04 — The SiLU table should be immutable statement data

`silu_int8_table()` recomputes the table at runtime with platform `f64::exp`
and then freezes its digest. The nearest rounding boundary in the current
table is not especially close, so this is unlikely to change a row on ordinary
platforms, but production statement semantics should not depend on libm.

Recommendation: check in the 256 integer pairs as a constant, define the exact
rounding rule unambiguously, and use floating point only in a generator/test
that proves the checked-in digest.

### M-05 — Transcript/proof byte counts are modeled, not measured

The cost documents price a K element at 64 bytes, but `KField::bytes` currently
hashes sixteen eight-byte words (128 bytes), and there is no proof wire format.
A future 31-bit packed encoding can reach the modeled size, but current
“~120 KB” and “~140 KB” figures are not serialized proof measurements.

Recommendation: implement the canonical encoding, round-trip it, and report
actual proof bytes rather than field-element arithmetic.

