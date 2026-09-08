# FA4 — Approved private-model consistency (P3 model identity): review and specification

**Reviewer:** Claude Fable 5.1, independent reviewer, 2026-09-07 session.
**Role:** independent identity review (task FA4 of `ZK60_FABLE_QUEUE.md`). Not the
implementer; `hashline/src/model_identity.rs` stays Codex-owned.
**Source pin:** worktree `/home/victor/wt-zk60-fa`, branch `zk60-fable-review`, HEAD
`52a13d1` ("docs: publish Fable follow-ups and minimal ZKP core refactor task").
**Files this review owns (new):** this document; `hashline/tests/zk60_model_identity.rs`;
`results/zk60_fable_fa4_*`. Everything else cited below was read, not edited.
**Companion record:** `results/zk60_fable_fa4_review.json` (the same facts, machine-readable).

Evidence classes used below: **[MEASURED]** = a number from a log in this repository that
this review reproduced or read; **[COUNTED]** = derived from source or from the project's
own accounting tool (`scripts/hashline_memory_plan.py`); **[DERIVED]** = a security argument
derived from the code in this session; **[EXTERNAL]** = a literature claim, with what was
and was not opened stated explicitly. Nothing here is a deployment security number.

---

## 0. The one-paragraph answer

Under P3 the FFN proof re-commits the weights with fresh pads, salts and mask rows on
every proof, so its W root changes every time and the verifier compares it to nothing;
the `model=` string in the statement header binds the prover to its DECLARATION and not
the declaration to the weights. Two different hidden weight tensors therefore verify
under one declared model, one statement and one input — reproduced here at the tiny
shape with the baseline's seeds (digests identical to Codex's I1 record), with new seeds,
and with fresh OS entropy (section 2). This is a **missing constraint**, and nothing in
the current tree enforces P3 identity. The repair is a **stable, independently approved
hiding commitment per layer** that the FFN proof opens directly, made safe for bounded
reuse by sizing its random pad and its mask-row sets for a public opening budget *k*
(section 5, construction (b)); the "fresh commitment + per-proof equality proof" form
(construction (a)) needs the same budgeted stable commitment AND keeps the per-proof
W commit that is today the largest P3 phase, so it is the rotation primitive, not the
per-proof one. The approval source is a signed manifest the verifier loads from its own
configuration; a model-name string or a root copied from the candidate proof cannot
satisfy it. The final construction must be reviewed with FA2/FA3 before any P3 product
acceptance; P1 private-block work does not wait for it.

---

## 1. What was reproduced, and how

### 1.1 Commands, exits, hashes

All Rust runs: CPU only, `HL_GPU=0`, two build/Rayon threads, detached under the shared
heavy lock with the `.done` marker protocol, in the review worktree (cold build cache).

| step | command (abbreviated; exact form in `results/zk60_fable_fa4_review.json`) | exit | log | SHA-256 of log |
|---|---|---:|---|---|
| R1 baseline diagnostic | `cargo test --release --offline --manifest-path .../hashline/Cargo.toml --test zk60_identity_gap -- --nocapture --test-threads=2` | **0** (5 passed) | `results/zk60_fable_fa4_identity_gap.log` | `bb3bd8e01c364c7a4239efc5579f61e2f319e5846cdf3007eb3ac35eb6f2c93f` |
| R2 new review tests, run 1 | same shape, `--test zk60_model_identity` | **101** (4 passed, 1 failed: my own row-consistency invariant, see 1.3) | `results/zk60_fable_fa4_model_identity_run1.log` | `4d0265e16bd26270c32c4998b698e1dc6d77d2d6b081e2c2fb5cdf04d4e9c348` |
| R3 new review tests, run 2 | same, after the invariant fix | **0** (5 passed, 1.63 s test time; 12.80 s rebuild) | `results/zk60_fable_fa4_model_identity_run2.log` | in the JSON record (computed after this table was written) |
| M1 memory accounting | `python3 scripts/hashline_memory_plan.py ...` (four configurations, section 6) | 0, 0, 0, 0 | `results/zk60_fable_fa4_memory_plan_*.json` | in the JSON record |

First build of the library in this worktree: 54.41 s (R1 log). The test binary rebuild
for R2 took 12.85 s. These are build times on a shared box, not measurements of anything.

### 1.2 Observed verdicts (R1, the baseline diagnostic)

`known_p3_gap_same_declared_model_and_input_different_weights_both_verify` PASSED, i.e.
both proofs VERIFIED:

| private weights | declared model | seed | proof SHA-256 (identical to I1's record in `ZK60_IDENTITY_WORKER.md`) |
|---|---|---:|---|
| Wg[0] = -1 (approved) | `example-approved-model` | 201 | `cbccb86231fef7714eb07232ea6b00d429e3f86df0d5a1d4f8f25655ead28606` |
| Wg[0] = 0 (substitute) | `example-approved-model` | 202 | `acddc82808299451d07c7997e3921bae0ffb9f0af3fdd561460697d6a48fdba5` |

The four `approved_p1_*` / `registration_*` tests also passed: the P1 boundary rejects a
valid substitute-weight proof at the root comparison, a relabelled root at the proof
verifier, and every changed statement/parameter/mode/commitment field.

### 1.3 Observed verdicts (R2/R3, the new review tests, `hashline/tests/zk60_model_identity.rs`)

Independent reproduction with different seeds (601/602), a different transcript domain,
and additionally with `seed: None` (fresh OS entropy). All four proofs VERIFIED under the
same statement and declared model `approved-model-A` [MEASURED, run 1 log]:

| case | W root (hex, first 16) | proof SHA-256 |
|---|---|---|
| approved, seed 601 | `afd0c74f1f837640…` | `a54cd628949bf83c0f6fb06e60e11fe457ad8aa2674fbed670008492623237ce` |
| substitute Wg, seed 602 | `de10ad2137bed2e0…` | `8ca1cfc1fb8edfbfb6537ee0f6119b5648fa5af4f9d952e9e8ed461301c64590` |
| approved, OS entropy | `fd5d6d2052f55810…` | (fresh randomness: not reproducible by design) |
| substitute Wg, OS entropy | `97a54d75c3c65415…` | (fresh randomness: not reproducible by design) |

Note the two "approved" roots differ from each other: the proof contains no stable
identity at all, not merely an unchecked one. The run-1 failure was the matrix test's own
invariant `enforced_today == (today == required)`, which I had applied to the two
reused-randomness rows although those are prover-side obligations no verifier verdict can
enforce; the fix adds an `Obligation::{Verifier, Prover}` field and applies the invariant
per kind. No verifier verdict differed from expectation in run 1. Run 2 is the record of
the corrected file (marker and hash in the JSON record).

---

## 2. What the P1 boundary enforces, and where

`hashline/src/model_identity.rs` (Codex, I1). The positive comparison for this review:
what an independently registered root buys, and what the caller must obtain on its own.

| check | where (file:line at 52a13d1) | what it pins |
|---|---|---|
| registration refuses P3 and predicates | `model_identity.rs:265-275` (`require_p1_commit`), called at `:105` and `:215` | there is NO approved-P3 boundary; the refusal message says so: "P3 approved-model consistency is not implemented" |
| registration validates shape, shift bands, PCS params, W commitment shape, table digest AND bytes against the frozen registry | `model_identity.rs:98-196` | the registered relation is well-formed; `num_col_checks` is a structural check, "not a security floor" |
| verify: mode/model declaration equality | `:215-218` (`ModeMismatch`) | the REGISTERED mode is what the verifier later receives |
| verify: every StatementV3 field equal | `:219-234` (`StatementMismatch(field)`) | l, t_rows, d, f, shifts, act, table digest, table bytes |
| verify: LayerParams equal | `:235-240` (`ParameterMismatch`) | log_cols, inv_rate, num_col_checks |
| **verify: the proof's W root/rows/log_cols equal the REGISTERED public commitment** | `:241-250` (`WeightCommitmentMismatch`) | the model identity under P1: the public weights' Ligero root, computed by the application from approved public weights BEFORE any proof exists |
| verify: NTT tables canonical | `:251`, `validate_ntt` `:279-306` | verifier-owned tables |
| verify: fresh local transcript in the registered domain, then `verify_layer_zk_v3` with the REGISTERED statement/params/mode | `:252-262` | the candidate's copies are never used |

What the caller must obtain independently of the prover (module header `:8-14`, `:22-24`):
the statement, parameters, W commitment and transcript domain, from authenticated
configuration or by recomputing the root from approved public weights. The tests do
exactly that (`zk60_identity_gap.rs`, `public_weight_commitment`, which calls
`pcs::commit` on the block-laid-out int8 planes and never reads a proof). The module does
not authenticate a registry, sign manifests, or derive trust from `model_id`; it cannot
detect reused prover randomness; exponents absent from `StatementV3` are not pinned.

Why P1 works and P3 does not: under P1 `prove_layer_zk_v3` commits W with the
deterministic `pcs::commit` (`zk.rs:2462`, via `wcache::commit_w`), so the root is a
function of the weights alone and is stable per model. Under P3 it calls
`pcs::commit_zk_owned` with pads, salts and mask rows drawn from the proof's RNG
(`zk.rs:2436-2460`), so the root is a function of the weights AND fresh randomness.
`verify_layer_zk_v3` absorbs whatever root the proof carries (`zk.rs:3505-3515`) and
checks the proof against it; the header `model=` field (`zk.rs:228-290`) is absorbed at
`zk.rs:3504` and binds the proof to the declared string, nothing more.

---

## 3. The missing P3 constraint, stated precisely (not as enforcement)

Let `C_i = (root_i, rows, log_cols)` be the hiding W commitment carried by P3 proof `i`
of layer `l`, and let `W_i` be the data rows it commits to (block layout `LayoutV3`,
`w_len = 3·d·f` field elements, followed by the `3·nb_d·nb_f + 1` mask rows of
`ZkLayoutV3::{w_mgu, w_mdd, w_prox}`, `zk.rs:2078-2080, 2148-2153`).

The FFN relation proven today is

> R_ffn(l, i): z16 = FFN_int(x; W_i, shifts, table) for the x, z16 committed in A_i,
> with W_i the data part of C_i,

and the header binds `(privacy, output claim, model string)`. **Missing:**

> R_ident(l, i): W_i = W*_l, where W*_l is the weight tensor of layer l of the model an
> independent approver evaluated and signed, and the verifier's knowledge of W*_l comes
> from that approver and not from the candidate proof.

Because C_i is re-randomised, `root_i` carries no information a verifier can compare to
an approved value; a copied approved root is refused only because the root is in the
transcript (the proof is bound to ITS OWN root, matrix row M3), which is binding, not
identity. Absent R_ident, a P3 proof establishes "some int8 weights of this shape, under
these shifts and this table, computed this output", not "this model". `PROOF_FUNCTIONS.md`
function 1 asks for "this exact model"; the P3 tier as built does not deliver it (the AM
honesty note in `PROGRESS_UPERF3.md`, "Stated, not fixed", remains exactly true at
52a13d1).

Two further identity facts the statement does not carry, found while reproducing:

* **Calibration exponents.** `V3Exps` (9 exponents, `export_v3.rs:68-85`) reach the
  statement only through the four signed shifts. The activation-table member pins two of
  them (e_g, e_a16 = the frozen `(e_in, e_out)`); the other seven can be moved in concert
  with the shifts held fixed (`exps(rescaled)` in the new tests moves e_x, e_u16, e_h16,
  e_z16 by +1 and e_wg by −1). The resulting statement is byte-identical and, at one seed,
  the PROOF is byte-identical (`gap_calibration_exponents_are_absent_from_the_statement_and_the_proof`).
  The proof relation is exponent-free by construction (it is an integer relation), so this
  is an input/output-contract obligation of the manifest, not a defect of the proof — but a
  verifier that decodes z16 at a scale it took from the prover has been handed the scale by
  the party it is checking. The manifest must pin the exponents and the verifier must use
  the manifest's.
* **Tensor position.** The layer index `l` is absorbed (`layer.rs:1396`), so a layer-1
  proof does not verify as layer 0 (row M12); but nothing binds WHICH hidden tensors sit
  at position l (row M11). Identity must be per layer: one approved commitment per layer.

---

## 4. The proposed relation, public inputs and API

### 4.1 Actors and trust (registration / authentication of the approved commitment)

| actor | holds | does |
|---|---|---|
| Model owner **O** | W (all layers), the prover, the secret commitment material | generates C*_l with fresh OS entropy; proves; tracks the opening budget |
| Approver **E** | W under agreement (E evaluated the model; it necessarily ran it) and O's commitment randomness for C*_l | recomputes C*_l bit-for-bit, checks the tensors against the evaluated export's digests, signs the manifest (or hands it to R) |
| Registry **R** (may be E) | signing key | publishes the signed manifest; optionally records used slots |
| Verifier **V** | R's public key from ITS OWN configuration | loads the manifest, verifies its signature, derives one `ApprovedP3Layer` per layer, verifies proofs |

The approval source is therefore independent of the candidate proof in the only sense that
matters: V's `ApprovedP3Layer` is constructed from the signed manifest, whose W roots were
recomputed by E from the evaluated tensors. A model-name string is a label inside that
manifest, never a trust source; a root copied from a proof cannot enter registration
(there is, as in I1, no `from_proof` constructor, and E's recomputation would fail on it).

Recomputation is deterministic: `commit_zk_owned` (`pcs.rs:620-672`) is a pure function of
`(data, pads, salts, coset)`, and pads/salts/mask rows are drawn from `ZkRng` in a fixed
order, so O hands E either the raw randomness or a `ZkRng` seed dedicated to registration
(from OS entropy, used for nothing else). E already knows W, so E learning the randomness
leaks nothing new; E must nonetheless treat it as O's secret. A model whose approver may
NOT hold the weights is out of scope for this construction (it would need a proof of
commitment well-formedness against a public hash — a SNARK over blake3 on 176 M field
elements — and is not proposed).

### 4.2 The manifest (what the verifier obtains, and what D_M covers)

Canonical bytes, digest `D_M = blake3(manifest)`, signed by R:

* model name / version (labels), the approval record identifier, validity, `k` (opening
  budget per layer commitment), the transcript domain;
* the v3 export identity: `sha256(digests.txt)` of the export sidecar (`V3Sidecar`,
  `export_v3.rs:97-160`: profile `v3-widened`, requant `round`, dims, zpolicy, per-layer
  shifts/exps/wexps/table rows, per-tensor sha256s) and the per-layer weight tensor
  digests it lists;
* per layer `l = 0..L-1`, in order: `StatementV3` fields (t_rows, d, f, shifts, act, table
  digest — table bytes are regenerated from the frozen registry `tables_v3.rs:134-141`),
  `V3Exps` (all nine), `LayerParams`, the stable commitment `C*_l = (root, rows,
  log_cols)`, its `ZkOpts { q_pad, coset }`, its W inverse rate, the mask-row layout
  version, and — as they become private (A09) — the same for the norm gains γ and the
  attention weights, as further rows of the same layer commitment or separate ones.

The statement header's `model=` field carries `hex(D_M)`; under the new profile it also
carries `layer=l` and `slot=i`. The verifier refuses any proof whose header differs from
the registered one (as `ModeMismatch` does today).

### 4.3 The relation (construction (b), recommended first implementation)

For layer l, slot i < k:

> **R_P3-ident(l, i):** the FFN relation R_ffn holds for x, z16 committed in fresh A_i,
> with the weight matrix opened FROM C*_l (the manifest's root), using mask-row set i of
> C*_l for the W block terminals and the proximity row, and a fresh CFS mask commitment,
> fresh A and H commitments, and fresh pads/salts for A and H.

Public inputs (all from the manifest, none from the proof): `D_M, l, statement_l,
exps_l, params_l, C*_l, ZkOpts_l, inv_rate_W, k, domain`. From the proof: `slot i`
(checked `< k`), the A/H roots, the CFS mask root, the openings. Verifier obligations:
(1) authenticate the manifest; (2) compare EVERY claimed field to the registered one
before any transcript exists (P1's discipline); (3) check `proof.w_com == C*_l` exactly;
(4) check `i < k`; (5) run the FFN verifier with the REGISTERED statement/mode and with
`ZkOpts_l` (not `ZkOpts::standard`) for the W opening; (6) decode z16 with the manifest's
exponents; (7) bind the request (nonce or I/O commitments) into the domain or statement
(row M13 — today a caller obligation, unchanged by this construction); (8) optionally
report `(D_M, l, i)` to R for double-use detection (privacy hygiene for O, not soundness).

Under (b), R_ident is definitional: the proof's W commitment IS the approved one. A prover
that runs the FFN on W' ≠ W*_l must still open C*_l's columns (it holds no other
preimage of that root) and the Ligero column check ties the clear combination vectors to
those columns, so substitution is caught by the same proximity/consistency argument that
catches a tampered W entry today (`am_r2`: "flipped Wg entry: REJECT").

### 4.4 Prover interface and API proposal (for Codex; sketches, not code)

```rust
// NEW module (name at Codex's discretion), registration side:
pub struct StableWeightCommitment {           // SECRET material; persist encrypted/at-rest
    cm: CommittedZk,                           // data rows + k * (3*nb_d*nb_f + 1) mask rows; q_pad = k * Q
    budget: u32, used: u32,                    // `used` is write-ahead persisted BEFORE each proof
    layout: StableWLayout, opts: ZkOpts, inv_rate: usize,
}
pub fn commit_stable_weights(wg_t, wu_t, wd_t, dims, params: &LayerParams, inv_rate_w: usize,
                             budget: u32, ntt: &NttTables, rng: &mut ZkRng) -> StableWeightCommitment;
impl StableWeightCommitment {
    pub fn commitment(&self) -> Commitment;   // goes into the manifest
    pub fn take_slot(&mut self) -> Result<u32, BudgetExhausted>;   // persists `used` first
}
// zk.rs (Codex): the prover takes the stable commitment instead of committing W.
pub fn prove_layer_zk_v3_stable_w(w: &V3Witness, t_rows, params, ntt, cfg: &ZkConfig,
                                  tr: &mut Transcript, stable: &mut StableWeightCommitment) -> ProveOutputZk;
// zk.rs (Codex): the verifier is TOLD the W commitment policy; it does not read it from the proof.
pub struct WeightPolicy { pub commitment: Commitment, pub opts: ZkOpts, pub inv_rate: usize, pub budget: u32 }
pub fn verify_layer_zk_v3_stable_w(st, proof, params, ntt, tr, mode, policy: &WeightPolicy, slot: u32) -> Result<(), String>;
// model_identity.rs (Codex): the boundary, mirroring ApprovedP1Layer.
pub struct ApprovedP3Layer { statement, exps: V3Exps, params, weights: WeightPolicy, mode, transcript_domain, required_ntt_log }
impl ApprovedP3Layer {
    pub fn from_authenticated_manifest(m: &ApprovedModelManifest, l: usize) -> Result<Self, IdentityError>;  // caller verified the signature
    pub fn verify(&self, claimed_statement, claimed_exps, claimed_params, claimed_mode, slot: u32,
                  proof: &LayerProofZk, ntt) -> Result<(), IdentityError>;   // new errors: BudgetExceeded, CalibrationMismatch
}
```

Concrete touch points in `zk.rs` (read at 52a13d1): the `is_p3` W branch
`zk.rs:2415-2468` (draws mask rows, asserts `wcache::dir().is_none()`, commits fresh);
`ZkLayoutV3` mask-row indices `zk.rs:2138-2153` (must address set i); `build_w_zclaims_v3`
`zk.rs:3292-3320` (the W terminal claims use `w_mgu[k]`/`w_mdd[k]`; index by slot);
`verify_layer_zk_v3` `zk.rs:3505-3515` (row-count check `w_rows_want`) and `:3738`
(`ZkOpts::standard(&w_pcs)` hard-coded — must come from the policy); `pcs_params(params,
lay.log_wb)` (W needs its own inverse rate); the header `zk.rs:270-290` (new profile tag so
`P1-v3` and the current P3 header bytes are untouched). `pcs.rs` needs no protocol change:
`commit_zk_owned` already accepts any `q_pad >= Q` with `n + q_pad <= nn`
(`pcs.rs:625-626`, `encode_row_zk` `pcs.rs:585-605`), and `verify_zk` checks the group
vectors at length `n + q_pad` (`pcs.rs:944-962`).

---

## 5. Construction comparison

### 5.1 The hiding budget, derived from the code [DERIVED]

`encode_row_zk` (`pcs.rs:585-605`) encodes a row as the polynomial
`f(X) + Z_n(X)·g(X)`, `f` the degree-<n interpolant of the message on the subgroup G_n,
`Z_n = X^n − 1`, `g` the degree-<q_pad polynomial whose coefficients are the pad, evaluated
on the coset `7·G_nn` (`coset_powers` asserts the coset misses G_n, so `Z_n ≠ 0` at every
evaluation point). For one row, let J be the union of column indices opened across all
proofs against this commitment, `|J| ≤ k·Q` (sampling is with replacement,
`transcript.rs:119-131`, so ≤ holds). If `|J| ≤ q_pad`, the map from the pad to
`(g(x_j))_{j∈J}` is a Vandermonde system on distinct points and is surjective, hence the
opened codeword values are uniform and independent of the message. **A stable commitment
with `q_pad ≥ k·Q` hides its opened columns perfectly across k proofs.** With `q_pad = Q`
(today, `ZkOpts::standard`, `pcs.rs:509-512`) the second opening already leaks; after
`(n+Q)/Q` openings the row is determined — this is lane ZZ's "65 proofs at n = 2^14"
(`U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md` section 1) and the reason `--wcache` is refused under
P3 (`zk.rs:2450-2455`). The same document already states the fix's direction for mask
rows: "in any cached-commitment design the masks must come from a fresh per-proof
commitment" — here, from a budgeted set of precommitted rows inside the same matrix,
because a Ligero group vector can only be checked against rows of the commitment it opens.

The other per-opening messages and what hides them, with what must be fresh per proof:

| message | hidden by | reuse rule under a stable C* |
|---|---|---|
| Q opened columns (all rows, with salts and paths) | the pad (above) | total distinct positions per row ≤ q_pad ⇒ budget `k ≤ q_pad / Q` |
| group vectors `v_g = Σ ρ_i (m_i‖p_i)` (`pcs.rs:934-960`) | a uniform mask row in the group with nonzero ρ | the group's mask row must be UNUSED by any earlier proof ⇒ one mask-row set per slot |
| proximity vector | the prox mask row | one prox row per slot |
| W block terminals `k.0·W_blk(p) + k.1·M_row(tail p)` (`zk.rs:3300-3302`) | the block's mask row evaluated at `tail(p)` | one row per block per slot (this is `w_mgu`/`w_mdd` today: `3·nb_d·nb_f` rows) |
| sumcheck rounds and their terminals | the CFS mask commitment (`mask_root`, fresh per proof, not part of W) | unchanged: fresh every proof |
| A, H commitments and openings | fresh pads/salts/masks per proof | unchanged |

Slot reuse (the same mask-row set in two proofs) leaks the difference of two W
evaluations; it is a privacy failure of the prover, not a soundness failure, and the
verifier cannot see it. Hence `used` is write-ahead persisted and slots are never
recycled; a crash between persist and proof burns a slot, never reuses one.

Soundness consequence of the pad: the row polynomials have degree `< n + q_pad`, so the
code is RS[nn, n + q_pad] with relative distance `1 − (n + q_pad)/nn`. At inverse rate 4
and n = 2^14: q_pad = Q gives 0.746; k = 16 (q_pad = 4096) gives 0.688; k = 64 (q_pad =
16384 = n) gives 0.5. Holding the distance at k = 64 means nn = 8n (inverse rate 8 for W
only). The proximity-test error as a function of distance and Q is FA5's obligation and
no number is inherited here; `model_identity.rs`'s P1 registration requires `inv_rate ==
4`, so the P3 policy is a new registration type in any case. The planner
(`scripts/hashline_memory_plan.py:71-72`) additionally requires `q_pad ≤ n`, so under the
current GPU implementation `k ≤ n/Q = 64` at n = 2^14; a larger budget needs the CL1
lane's kernels checked, not a protocol change.

Whether the k-fold reuse is zero-knowledge as a WHOLE (columns, group vectors, terminals,
CFS masks, two Fiat–Shamir layers, k slots against one Merkle root) must be written as a
simulator: commit to a uniformly random matrix with random pads and mask rows; because ≤
q_pad positions per row are ever opened and every group/prox/terminal message carries an
unused uniform row, the k transcripts' distributions coincide with the honest ones. That
argument is straightforward but is NOT written or checked here; it is the FA2/FA3 item.

### 5.2 Citations and what was and was not confirmed [EXTERNAL]

* **Scorpius / repaired Orion, ePrint 2024/1164.** NOT opened in this session (no network
  use was made; nothing here should be read as checked against the PDF). What this
  repository's earlier reviews recorded from it: the abstract ("Orion in its current
  revision is still unsound (with and without the zero-knowledge property)"; the corrected
  scheme keeps the linear-time prover) in `U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md` §3.1, and,
  from the revised paper's sections 4.5/4.7/5.1 as read by the R2 memo
  (`ZK60_RESEARCH_DECISIONS.md`, "Scorpius: an explicit warning against unbounded private
  reuse"): Theorem 4 assumes a suitable randomized code AND a knowledge-sound ZK outer
  commit-and-prove SNARK; **section 4.7 rules out running Eval repeatedly while retaining
  its ZK goal** — the multipoint extension combines evaluations into ONE Eval. Consequence
  for this design, taken at face value from those readings: the reusable construction (b)
  invokes Eval k times on one commitment and therefore does NOT rest on Scorpius's theorem;
  it rests on the explicit bounded-reuse padding/masking argument of 5.1, which must be
  proven on its own. Within one proof, the W opening is one batched multipoint `open_zk`
  call (one Eval), consistent with the batched interface the memo describes.
* **ZK-Ligero padding (Ames, Hazay, Ishai, Venkitasubramaniam, CCS 2017).** The
  pad-makes-any-≤q-positions-uniform argument is, to this reviewer's recollection, the
  standard one from that line; the code identifies itself only as "a Ligero/Brakedown-class
  multilinear polynomial commitment" (`pcs.rs:1`) with the ZK form tagged `[UPERF3-ZA]`
  (`pcs.rs:481`), and does not cite the paper. The attribution is from memory and the paper
  was not opened this session; the derivation in 5.1 is self-contained from `encode_row_zk`
  and Vandermonde invertibility and does not depend on it.
* **Orion (ePrint 2022/1010), code switching:** referenced only through
  `U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md` §3 as "option 2" (never send the sampled columns;
  prove the column check inside an inner ZK argument over an arithmetic hash). Not opened.
  It is the unbounded-reuse alternative (section 5.4) and is not proposed as the first
  implementation.

### 5.3 (a) versus (b), counted

Shape for counting: the 8B FFN layer, d = 4096, f = 14336, log_cols 14 (n = 2^14),
Q = 256, W data rows 10752 (`3·d·f / n`), block-mask rows per proof 22
(`3·nb_d·nb_f + 1` with nb_d = 1, nb_f = 7), T = 512. Memory numbers are from
`scripts/hashline_memory_plan.py` at 52a13d1 (the M1 planner: GPU allocation-lifetime
accounting for ONE unchunked hiding commitment; `measured: false`), JSONs in
`results/zk60_fable_fa4_memory_plan_*.json`. Time anchors are from
`results/am_r2_mistral.log` (2026-09-04, WSL laptop, 8 GB card, noisy shared box).

| item | (a) fresh C_i per proof + registered C* + per-proof equality proof | (b) the FFN proof opens the registered C* directly (recommended) |
|---|---|---|
| **preprocessing (per registration, per layer)** | one budgeted commit of C* (below) | the same one budgeted commit; E recomputes it |
| **per-proof W commit** | today's: `commit W 8.417 s of 15.824 s` prove at Mistral T=512 on the CPU path because the GPU commit failed to allocate 5387 MB [MEASURED, am_r2 P3 block]; accounted GPU peak of one P3 W commit 13,492 MiB [COUNTED, planner k=1] | **none** (the largest P3 phase disappears; on the 8 GB card it did not fit at all) |
| **per-proof W opening bytes** | today's opening of C_i (unchanged) PLUS an opening of C*: Q·rows·8 B = 256·12160·8 = 24.9 MB of columns + 256·17·32 B paths + clear vectors ≈ **+26 MB per layer proof** [COUNTED] | today's W opening with rows 10774 → 12160 (+1386 mask rows ≈ +2.8 MB) and group vectors at n + q_pad instead of n + Q (+0.26 MB per group) ≈ **+3 MB per layer proof** [COUNTED]; baseline P3 proof 40,251,860 B at T=512 [MEASURED] |
| **per-proof extra argument** | a masked equality sumcheck over 2^28 padded W positions (3 tables of Fp2 = 4.3 GB each if materialised; streamable) + one extra CFS mask commitment + the extension round (`private_seam.rs` shape, generalised from ≤ 4096 values to 3·d·f) | none |
| **per-proof prover memory for W** | fresh C_i resident (13.5 GiB accounted peak at 8B, GPU) + the stored C* columns | Q columns read from the stored encoded C* (24.9 MB) + the systematic W for the block sumchecks (1,412 MB as Fp, 176 MB as int8) |
| **stored secret material per layer** (O's disk) | C*: below, plus nothing else persistent | C*: encoded matrix 5,552 MiB (k=16, rate 4) / 6,080 MiB (k=64, rate 4) / 12,160 MiB (k=64, W rate 8); or the host-retained payload only (1,741 / 3,046 / 3,052 MiB: data + pads + salts + tree) with the Q columns re-derived per proof [COUNTED, planner]. For 32 layers: ≈ 174–380 GiB of stored codewords, or 54–95 GiB of payload |
| **registration commit peak** (GPU, unchunked) | 14,231 MiB (k=16, rate 4) / 16,724 MiB (k=64, rate 4) / 28,887 MiB (k=64, rate 8) [COUNTED, planner]; off the per-proof clock; the CL1 chunked commitment or the CPU path applies | same |
| **soundness** | FFN soundness + equality-sumcheck error (≈ 2·28 / |F_p²| ≈ 2^-122, negligible) + the C* proximity test at the budgeted rate | FFN soundness with the W proximity test at the budgeted rate (5.1); no added sumcheck |
| **ZK composition** | two hiding commitments per proof, each opened once per proof; C* budgeted exactly as in (b) — (a) does NOT escape the budget | one budgeted commitment, k slots; simulator to be written (5.1) |
| **budget exhaustion** | re-register, OR rotate: prove C*_new ≡ C*_old with the equality argument, consuming one slot of C*_old, and have R sign C*_new without E recomputing | re-register (E recomputes) — or use (a) as the rotation step |
| **identity check at the verifier** | `consistency.left == proof.w_com`, `consistency.right == C*_l`, both proofs verify | `proof.w_com == C*_l` (one comparison, P1's discipline) |

Reading: (a) costs strictly more per proof than (b) on every row and buys no privacy over
(b), because the stable commitment is opened once per proof in both. Its one distinct use
is **rotation** (C*_old → C*_new without the approver's recomputation), which is why it is
specified and not discarded. The honest caveat on (b): it changes the FFN prover's W path
(Codex-owned `zk.rs`), the W inverse rate becomes a per-policy parameter, and the whole
scheme now stores long-lived secret material (pads, salts, mask rows, slot counter) that
must be protected and never rolled back.

### 5.4 Alternatives documented, not proposed first

* **Option 2 of lane ZZ (never reveal columns; inner ZK proof of the column check under an
  arithmetic hash):** unbounded reuse, no budget, no stored-column leakage; costs a
  Poseidon2 outer tree and an inner prover (~1e9 constraints per proof at 30B per that
  memo's count) and, per that memo, a written simulator because the lineage was found
  unsound. The measurement that would justify moving to it: (b)'s registration cost at the
  budget the product needs (proofs per day ÷ k re-registrations) exceeding the inner
  prover's per-proof cost.
* **Option 3 (lattice-hybrid, re-randomisable Ajtai commitment for W):** hiding across
  unbounded openings by fresh randomness, but a cross-engine (modulus) link proof; ZZ §4
  prices the opening at 100–1,000× the hash line's.
* **Commitment chaining (C_i ≡ C_{i−1}):** makes each proof's verification depend on all
  earlier proofs; rejected because an independent verifier must verify one proof alone.

---

## 6. The adversarial matrix

Verdicts: **today** = observed at 52a13d1 by the review tests (asserted there); **(b)** =
required of construction (b). `enforced_today` = today equals the requirement. Rows M1–M18
are the test rows of `matrix_adversarial_cases_state_enforced_today_and_assert_the_observed_verdict`;
G1–G4 are design rows not testable at the FFN v3 API today.

| id | case | today | required (b) | enforced today | mechanism after repair |
|---|---|---|---|---|---|
| M1 | substitute W (Wg entry), same statement/model/input, P3 | ACCEPT | REJECT | **no** | `proof.w_com ≠ C*_l` before any transcript; a prover holding C*_l but running W' fails the column check |
| M2 | substitute W (Wd entry) | ACCEPT | REJECT | **no** | same |
| M3 | copied candidate root (substitute proof relabelled with another proof's root) | REJECT | REJECT | yes (binding, not identity) | root in transcript + Merkle paths; unchanged |
| M4 | changed table digest in the claimed statement | REJECT | REJECT | yes | absorbed (`layer.rs:1404`); boundary compares to manifest first |
| M5 | changed shifts | REJECT | REJECT | yes | absorbed (`layer.rs:1402`) |
| M6 | changed calibration exponents, same shifts/table | ACCEPT | REJECT | **no** | boundary compares claimed `V3Exps` to the manifest; `D_M` in the header; verifier decodes with the manifest's exponents (the proof relation itself is exponent-free) |
| M7 | proof declared model A, verified as model B | REJECT | REJECT | yes | header; after repair `model=D_M` and `C*_l` differ too |
| M8 | declared model A, verified with no declaration | REJECT | REJECT | yes | header |
| M9 | false declaration: substitute weights DECLARED as model A | ACCEPT | REJECT | **no** | = M1 from the prover's side |
| M10 | P3 proof presented as P1 | REJECT | REJECT | yes | header + row counts |
| M11 | layer swap (tensors): another layer's weights under this layer's statement | ACCEPT | REJECT | **no** | one `C*_l` per layer; `proof.w_com ≠ C*_l` |
| M12 | layer swap (index): l=1 proof under the l=0 statement | REJECT | REJECT | yes | `l` absorbed |
| M13 | replay of one proof for two requests, same domain | ACCEPT | REJECT | **no** | request nonce / I-O commitments bound into the domain or statement — a CALLER obligation that (b) does not change; the pass API must absorb it |
| M14 | replay under another transcript domain | REJECT | REJECT | yes (only if the caller binds the request) | unchanged |
| M15 | reused randomness, same witness (identical proofs) | ACCEPT | ACCEPT | n/a (prover) | undetectable by any verifier; OS entropy; `Some(seed)` in tests only; slot counter removes W-mask reuse by construction |
| M16 | reused seed across different witnesses: identical `mask_root` | ACCEPT | ACCEPT | n/a (prover) | as M15; the test shows the randomness stream is witness-independent, so reuse is visible to anyone holding two proofs |
| M17 | P1: substitute weights at the registered boundary | REJECT | REJECT | yes | the positive comparison |
| M18 | P1: honest registered proof | ACCEPT | ACCEPT | yes | the baseline (b) reaches with a hiding root |
| G1 | substitute γ (norm gains) under P3 | not testable (attention/norm path is P0; `norm.rs`, `attention.rs`) | REJECT | — | γ rows in the layer's stable commitment (A09) |
| G2 | replayed CONSISTENCY proof under another model / request (construction (a)) | n/a (no consistency proof exists) | REJECT | — | the equality transcript absorbs `D_M`, `l`, both roots and the request context (as `private_seam.rs:239-252` absorbs the spec digest and both roots) |
| G3 | slot ≥ k (budget exhausted) | n/a | REJECT | — | verifier check; prover refuses first |
| G4 | slot double-use | n/a | ACCEPT (soundness intact; prover privacy lost) | — | write-ahead `used`; registry double-use detection optional |

The test asserts the exact set of not-enforced rows `{M1, M2, M6, M9, M11, M13, M15, M16}`;
when the repair lands this set must shrink deliberately (rows flipped and the test
rewritten), and it may never grow silently.

---

## 7. Implementation handoff (files, owners, order)

P1 private-block work (A03–A08 in `ZK60_PRIVATE_BLOCK.md`) proceeds after its shared
privacy prerequisites WITHOUT waiting for any of this; the P1 identity boundary exists.
A09 ("P3 block extension and approved private-weight consistency") is gated on this
construction being reviewed, "a separate reviewed protocol milestone, not a flag flip".

| step | what | owner | files | acceptance |
|---|---|---|---|---|
| H1 | FA2/FA3 review of section 5.1's bounded-reuse argument: write the simulator for k slots against one Merkle root; joint base-field mask rank of the W group vectors with budgeted mask rows; the changed-rate proximity bound (with FA5) | Fable (FA2/FA3), FA5 | new review docs under `docs/zkmatrix-poc/` | a written simulator and a stated error bound as a function of (n, q_pad, nn, Q) |
| H2 | budgeted stable commitment type: `commit_stable_weights`, persistence, write-ahead slot counter, refusal at budget; CPU first | Codex (new module) | new `hashline/src/<stable_weights>.rs`, `lib.rs` registration | round-trip persist/load; slot counter monotone across crash simulation; `q_pad = k·Q` checked against `n + q_pad ≤ nn` |
| H3 | prover path: `prove_layer_zk_v3_stable_w`; mask-row indexing by slot; W inverse rate as a policy parameter; new header profile tag; the `--wcache` refusal replaced by the budget check | Codex | `hashline/src/zk.rs` | the four frozen P1/P3 fixtures byte-identical; new P3-stable fixture with its own digest |
| H4 | verifier path: `WeightPolicy`, `ZkOpts` from policy at `zk.rs:3738`, slot check, row-count check | Codex | `hashline/src/zk.rs` | tamper battery rejects with the stable W; substitute W rejects (flip M1/M2/M9/M11) |
| H5 | `ApprovedP3Layer::from_authenticated_manifest` / `verify`; manifest struct + canonical bytes + `D_M`; `V3Exps` comparison (flip M6); signature verification hook (the crate does not pick a signature scheme) | Codex | `hashline/src/model_identity.rs` (theirs), new manifest module | the review tests rewritten: every `gap_*` flips; matrix `missing` set shrinks to `{M13, M15, M16}` until the pass API binds requests |
| H6 | CL1 coordination: chunked commit at the budgeted width; planner `q_pad ≤ n` limit revisited; stored-codeword vs re-derive-columns decision (disk 174–380 GiB vs compute) | Claude GPU/PCS lane | `gpu/cuda.rs`, `scripts/hashline_memory_plan.py` | planner rows for the chosen k and rate; a forced-chunk CPU/GPU parity run |
| H7 | pass-level identity: absorb `D_M` once, `(l, C*_l, slot_l)` per layer in order, seams (X_{l+1} = Z_l) via the pending-FFN interface; request binding | Codex + Fable review | `chain.rs`, pending-FFN, `model_identity.rs` | wrong-order / missing-layer / mixed-model pass rejects |
| H8 | rotation via construction (a) (optional, later): W-scale equality proof consuming one slot of C*_old | Codex, after H1–H5 | new module generalising `private_seam.rs` | C*_new signed by R without E's recomputation |

Ordering rationale: H1 can start now and in parallel with H2 (H2 is deterministic
plumbing whose security depends only on H1's conclusion about k, q_pad and rate); H3–H5
touch Codex's files and land as one reviewed profile; H6 is needed for real widths but not
for the tiny-shape gates; H7 is the product boundary and is already listed as a separate
obligation by I1.

---

## 8. Review requirement before product acceptance

No P3 product acceptance may cite this document alone. The final construction — the
budgeted stable commitment, the changed W rate, the slot mechanism, the manifest and its
header binding, and the pass-level composition — must be reviewed with FA2 (mask-rank /
disclosure) and FA3 (the repaired profile) and its parameters closed with FA5 before any
P3 proof is presented as "this exact model". The tests in
`hashline/tests/zk60_model_identity.rs` are a record of the missing constraint and a
tripwire for unreviewed changes, not an acceptance gate for the repair.

---

## 9. Limits of this review

* Tiny shapes only (T=2, d=f=16, log_cols 5, Q=12); no GPU; no real-width run; the counted
  memory rows come from the M1 planner (unchunked GPU accounting, `measured: false`) and the
  one time anchor from a noisy shared-box log.
* ePrint 2024/1164 was NOT opened; its content is cited only as recorded by earlier reviews
  in this repository, and the construction deliberately does not rest on its theorem.
  The Ligero padding paper was not re-opened; the hiding argument is derived from the code.
* The bounded-reuse simulator is stated, not written (H1). No soundness number is given for
  the changed W rate (FA5). Joint mask rank of the budgeted group vectors is not audited
  here (FA2).
* γ and attention weights are covered by the design (same relation per tensor) but not by
  any test; the attention path is P0 at 52a13d1.
* Request binding (M13) and the pass-level composition are named obligations, not designed
  here beyond section 7 H7.
* The manifest signature scheme, key distribution and revocation are application choices
  outside the crate; the design requires them and does not supply them.
* Run 2 of the review tests (the corrected file) is recorded by its marker and log hash in
  `results/zk60_fable_fa4_review.json`; if that marker is not `0`, the file's pass status
  is not claimed.
