# U-S tranche ledger — the security boundary (audit Phases 1 + 2, then 3)

Branch: perf/zk-batch-optimizations. Spec: codex-audit-2026-07-12/
REMEDIATION_PLAN.md Phases 1-3 + FINDINGS.md C-01/C-02/C-03/H-03/H-05.
Opened 2026-07-14 after the U-R tranche closed (4713fa1).
Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: python3 -m unittest discover -s tests (42 tests + freeze-check green at every commit; LKP-5..9 digests/gates must not move unless a change is deliberate AND re-frozen with a dated note).
Heavy runs: each agent wraps its ONE heavy process in systemd-run --user --scope -p MemoryMax=5G (suites peak ~3.5G; no big benches in this tranche). codex-audit-* stays read-only.
NOTE: PROGRESS.md's old "Do NOT touch src/manifest.rs" rule was U-K8-tranche
lane protection, not policy — Phase 2 IS manifest work (and c377d0d already
extended it). Superseded for this tranche.

## Lanes and file ownership (two parallel agents)

- Agent P1 (Phase 1, ZK boundary, MAIN checkout): zkmatrix-rs/src/ring/**
  (entropy/nonce plumbing, mask/blinder consumption, lookup/gkr_masked/
  ct_engine internals) + ring_matmul.rs (verifier-side h0_lkp recomputation,
  the [U-S1] attack battery) + this ledger's P1 boxes. NOT manifest.rs,
  NOT structured_matrix.rs / lattice_matmul.rs, NOT docs/**.
- Agent P2 (Phase 2, Statement v3, WORKTREE): zkmatrix-rs/src/manifest.rs
  (+ a new statement module if cleaner), structured_matrix.rs /
  lattice_matmul.rs call-site ports, tests/ additions for its negative
  vectors ONLY (no edits to existing tests), MINIMAL localized
  ring_matmul.rs edits confined to statement-construction call sites
  (the orchestrator merges; keep the diff surgical). NOT ring/** internals.
- Orchestrator (after both): merge P2, resolve ring_matmul.rs overlaps,
  suite green, push, then open Phase 3 (proof artifact) on the merged base.

## P1 deliverables (audit Phase 1; exits are the audit's, verbatim in spirit)

- [x] P1-D1 DONE 2026-07-14. Audit: c377d0d already routed EVERY prover
      secret on the shipped Rust proof paths through `ProverRng`
      (from_os / from_test_seed) — verified by inspection of the RNG sinks
      in ct_engine.rs (sample_g_masks, sample_ct_masks, sample_arp_mask,
      arp_attempt_joint, prove_ct_round mask draws), sigma.rs
      (gaussian_ivec + rejection_accept), commit.rs (rho_ternary), and the
      mask/blinder draws in gkr_masked.rs; the only remaining `splitmix64`
      uses in ring_matmul.rs generate WITNESS/statement data (a harness
      concern), never a proof coin. The audit's C-01 quote ("SplitMix/
      fixed/public seeds on every proof path") was TRUE at audit time but
      already closed by c377d0d before this tranche. What I ADDED: an
      EXPLICIT proof-session nonce on `ProverRng` (mod.rs) — from_os reads
      it from the OS CSPRNG at the head of the session (before any secret),
      from_test_seed derives it deterministically; `session_nonce()`
      exposes it; the [U-S1] same-seed arm asserts two from_os sessions
      carry distinct nonces + distinct masks. Pinned entropy stays behind
      the explicitly harness-labeled `from_test_seed` (cf55852 pattern).
- [x] P1-D2 DONE 2026-07-14. The `Cell<bool> used` field is GONE from
      MaskSet (gkr_masked.rs), along with `is_used` and
      `harness_reset_freshness` (the flag-as-security-claim). `masked_gkr_
      prove` now CONSUMES `masks: MaskSet` BY VALUE (move); MaskSet has no
      `Clone`, so a second prove with the same object is a COMPILE error —
      reuse has no runtime path in the shipped API. The only reuse path is
      the explicitly-named `harness_clone` (attack-modelling tool); every
      caller of it is a battery that MODELS reuse. Shipped call sites
      (ffn_chain, ffn_layer) move the masks in and build the descent pins
      from the zero-mask SHELLS (weights are shape-only — identical to what
      the verifier already used), so the consumption is transparent. Note:
      blinders are still consumed into trees by reference (their freshness
      likewise rests on OS entropy + h0-binds-alpha-after-commitments,
      which was already shipped); the Cell-flag security claim was on masks
      only, and that is what the audit named — closed.
- [x] P1-D3 DONE 2026-07-14. c377d0d already recomputed expected_h0_lkp in
      the verifier AND seeded its transcript from it — but it ALSO carried
      the prover's `claimed_h0_lkp` (+ `alpha_p`) in the proof tuple and
      REJECTED by comparing `expected == claimed` / `av == alpha_p`. That
      is exactly the "reject by comparison" the audit forbids. Closed:
      `claimed_h0_lkp` and `alpha_p` are REMOVED from the proof tuples in
      BOTH ffn_chain and ffn_layer (the lkp/lkp_r tuples are now just the
      descent proofs). The verifier DERIVES h0_lkp from statement+full
      commitment list, seeds the transcript, derives alpha, and USES them
      — nothing prover-supplied is read or compared. The transcript-
      boundary battery legs are upgraded from "flip the transmitted copy"
      to "the prover builds its WHOLE lookup transcript on a free
      (arbitrary) prehash": the verifier's independent derivation makes the
      masked descents diverge and REJECT. [U-S1] adds a stale-h0 leg
      (prehash omits the commitment digest) — also rejects by derivation.
      Verified: U-K8 LookupH0 leg green in self-test; U-R1b LookupH0 leg
      green in `ffn-chain layer battery` (73s); [U-S1] two-process free/
      stale-h0 both REJECT in a second process.
- [x] P1-D4 DONE 2026-07-14. New `self_test_us1_boundary()` +
      `us1-battery` / `us1-verify` subcommands (ring_matmul.rs), run in
      self-test. Toy committed masked-lookup shape (dw=dt=6, T=8, 10 honest
      leaves): masked descents + blinded root cross-check = the lookup
      soundness core. Arms, all GREEN:
      * public-mask leak (broken harness): masks publicly RECONSTRUCTIBLE
        -> the attacker rebuilds the exact masked basis and recovers the
        multiplicity histogram m EXACTLY (consistent, == m) — C-01 is real.
      * closure (secret masks): the SAME recovery against secret fresh
        masks FAILS (the zero-mask basis cannot fit the masked transcript;
        inconsistent, != m).
      * duplicate-session refusal: from_os sessions draw DIFFERENT masks;
        move-by-value + no-Clone makes a second prove a compile error.
      * same-seed: two from_os sessions carry DISTINCT session nonces.
      * two-process: prove here, DUMP the current transcript encoding to
        bytes (minimal bounds-checked dump/load — NOT the Phase 3
        artifact), and a SECOND ring_matmul process (`us1-verify <file>`)
        loads + verifies. Honest -> ACCEPT (exit 0); free-h0 and stale-h0
        -> REJECT (exit 1). The child RECOMPUTES h0 from statement +
        commitment digest; no prover-local value crosses the boundary.
- [x] P1-EXIT MET 2026-07-14 (at the ZK-core toy shape). The [U-S1]
      two-process leg demonstrates the exact exit bar: a SECOND
      ring_matmul process ACCEPTS an honest proof, and the public-mask
      (recovery fails on secret masks), same-seed (distinct nonces/masks),
      free-h0, stale-h0 (both REJECT in the child), and reuse (compile-
      error / no-Clone) attacks all reject at the API boundary. Scope
      honesty: the two-process verifier exercises the masked-descent +
      root-cross-check soundness core with a MINIMAL dump/load, not the
      full Ajtai-committed ct-round; the block/layer rigs (self-test +
      `ffn-chain [layer] battery`) exercise the free/stale-h0 rejection on
      the FULL committed path in-process. A single fresh-process verifier
      over the COMPLETE committed proof is Phase 3 (H-05 proof artifact),
      opened by the orchestrator after P1+P2 merge — recorded, not
      closable in this tranche.
      External item (recorded, NOT DONE here): independent cryptographer
      review of Q4.7-Q4.9 + FS composition (audit Phase 1 item 6).

## P2 deliverables (audit Phase 2)

- [x] P2-D1 Typed integer semantics: raw encoding + scale-exponent
      conventions frozen in a typed spec; rescale scale propagation
      enforced even when a range proof narrows magnitude (C-03a);
      signed bounds asymmetric (or pos/neg checked separately).
      DONE 2026-07-14: the typed spec is the "Statement v3 — TYPED
      INTEGER SEMANTICS" block in manifest.rs (raw two's-complement
      encoding, value = raw * 2^-frac_bits, per-op scale equations);
      QuantMeta::raw_bounds() + RawBounds interval arithmetic propagate
      lo/hi separately (the +2^(w-1) endpoint rejects); the rescale scale
      equation was already unconditional since c377d0d — kept, and now
      Hadamard/Add gained the same PROVEN-narrowing rule (needed to type
      the lattice ReLU) while matmul accumulators can never narrow.
- [x] P2-D2 Typed TableSpec bound by exact metadata equality (digest,
      input/output quantization, domain) — not merely a nonzero digest.
      DONE 2026-07-14: TableSpec {digest, input, output, domain_min/max}
      with canonical SILU_INT8_TABLE_SPEC; header binds Option<TableSpec>
      (None only for lookup-free statements); Lookup validation requires
      digest == frozen digest, spec == canonical spec (exact equality),
      and operand quants == spec input/output. Digest parity with
      ring/lookup.rs asserted at every ring construction site.
- [x] P2-D3 Statement v3 validation: acyclic topologically-ordered DAG,
      nonempty ops, orientation/role checks (LinkEqual per its own doc),
      output visibility, modulus capacity, canonical padding; bare
      ClaimManifest::digest() disabled outside migration tests.
      DONE 2026-07-14: STATEMENT_VERSION = 3; new gates EmptyOperations,
      NotTopologicallyOrdered (reads must follow some producer),
      NoOutputs, BadModulus/ModulusCapacity (header modulus_bits =
      floor(log2 q); entry injection + per-op worst-case centered-window
      checks, applied even to narrowed ops), PadSpec canonical padding
      (PadCount/NoncanonicalPadding); LinkEqual orientation was already
      enforced (c377d0d) — kept. ClaimManifest::digest() is now PRIVATE
      (Statement::digest is the only transcript source); a #[cfg(test)]
      digest_v1_migration_only remains for migration tests.
- [x] P2-D4 Ports: structured, lattice, ring, inventory, chain paths on
      the same statement type (the audit H-03 list: structured_matrix.rs
      3646-class and lattice_matmul.rs 3212/3516/3865-class call sites).
      DONE 2026-07-14: structured chain-demo (3 digest sites), lattice
      chain-demo/gadget-demo/ffn-demo (7 sites), ring chain-demo,
      statement-inventory, U-K8 ffn-chain, U-R1 layer rig all derive ctx
      from validated v3 statements with honest integer typing (the
      structured/lattice demo witnesses were already small integers; the
      lattice ReLU types through the new narrowing rule). ONE shim-class
      exception recorded: ring self-test's [M5] wide-object battery seeds
      its transcript from the wide digest directly (random mod-q vectors
      carry no integer-typed statement) — see PARTIAL note in the log.
- [x] P2-EXIT negative tests cover: inconsistent fraction bits, +2^(w-1),
      cycles, empty add, wrong table digest/scale, dangling roles,
      noncanonical padding.
      DONE 2026-07-14: statement_negative_battery() in manifest.rs (22
      vectors + positive control), exposed as `lattice_matmul
      statement-negatives`, driven by NEW tests/test_statement_v3.py
      (battery + ported gadget-demo positive control + 737-entry
      inventory validation). The ring [U7v] battery in chain-demo keeps
      its 18 in-chain vectors (updated for v3 signatures).

## Phase 3 (opened by the orchestrator AFTER P1+P2 merge)

Canonical PublicStatement/ProverInput/Proof/VerificationError types;
serialization with lengths, versioning, canonical field encodings,
resource limits; verifier in a fresh process from statement bytes +
proof bytes + verified setup ONLY; fuzz/truncate/reorder every component
(errors, never panics); model digest from architecture + quantization/
table spec + all weight commitments.

## P3 deliverables (audit Phase 3; opened 2026-07-14 after merge e1f5dce)

Flagship path decision: the COMPLETE committed masked-LOOKUP proof
(statement -> commitments -> masked descents -> aggregate pins -> Ajtai
ct-round), purpose-built for serialization rather than refactoring the
fragile interleaved ffn_layer_run. This is the security-critical ZK core
of the whole tranche and carries a REAL Ajtai ct-round (not just the
descent core). The full FFN-layer CHAIN (range grounding + Hadamard +
multi-wave zeta streaming on top of this) reuses the same serialization
+ verifier primitives; its multi-wave orchestration is recorded PARTIAL.

- [ ] P3-D1 Canonical types: `PublicStatement` (v3 Statement canonical
      bytes), `Proof` (commitments + masked descents + ct-round),
      `VerificationError` (structured, never panics); ProverInput stays
      prover-side.
- [ ] P3-D2 Serialization: versioned header, length-prefixed components,
      canonical field encodings, hard decode-time resource limits derived
      from the statement (not the wire); reject-don't-truncate.
- [ ] P3-D3 Independent verifier: `verify <statement.bin> <proof.bin>`
      subcommand, fresh process from statement+proof+CRS derivation ONLY;
      recomputes every transcript seed (h0_lkp, alpha, psi, ct-round h0)
      from the decoded statement + commitments.
- [ ] P3-D4 Malformed-input robustness: fuzz/truncate/reorder/bit-flip
      every component class -> structured error, NEVER panics; a battery
      leg per component class + a fixed-seed randomized fuzz leg.
- [ ] P3-D5 model_digest: derived from architecture shape + quant/table
      spec + ALL weight-class commitments; wired through the v3 header;
      negative leg: one weight commitment swapped -> digest differs ->
      REJECT.
- [ ] P3-EXIT canonical byte size recorded (vs 256 KiB budget, honest);
      independent verifier p50/p95 at 2^12/2^16 [NOISY-SHARED]; NO
      prover-local value available to verification.

## Log

- 2026-07-14: tranche opened; P1 + P2 agents launched in parallel.
- 2026-07-14 (P1): closed P1-D1..D4 + P1-EXIT. Files: ring/mod.rs
  (ProverRng struct + explicit session_nonce), ring/gkr_masked.rs
  (MaskSet: Cell<bool>/is_used/harness_reset_freshness removed;
  masked_gkr_prove consumes by value; no Clone), bin/ring_matmul.rs
  (h0_lkp fully verifier-derived on block chain + layer rig; [U-S1]
  battery + us1-verify/us1-battery subcommands). Gates: ring_matmul
  self-test GREEN (312s, includes [U-S1]); `ffn-chain layer battery`
  GREEN (73s); `us1-battery` GREEN (0.12s). Python suite GREEN: 42 tests
  + freeze-check pass (341s, "OK"); LKP-5..9 freeze gates unmoved.
- 2026-07-14 (P2): Statement v3 landed (manifest.rs) + all H-03 call-site
  ports + negative battery; suite green (42 -> 45 tests). Notes:
  - PARTIAL/shim (one site): ring self-test [M5] wide-object battery no
    longer uses a manifest digest as ctx — it seeds its transcript from
    the wide-object digest directly (uk8_sha), because its witnesses are
    random full mod-q polynomials with no honest integer typing; wide
    entries in production chains bind through validated statements. Any
    future integer-typed wide path must construct a real v3 statement.
  - Statement digests MOVED v2 -> v3 by design (version bump + new bound
    fields). No frozen LKP-5..9 gate pins a statement digest (they pin
    derive-time parameter budgets), so freeze rows are untouched; both
    demo negative legs that previously exploited "reordered manifest
    still digests" now assert v3 REFUSES to digest reordered entries.
  - model_digest semantics (architecture + quantization + all weight
    commitments) remain Phase 3 scope per the remediation plan; v3 keeps
    the nonzero-digest gate only.
  - U-R1 layer-rig X-entry PadSpec declares dense msg_r*D packing and
    Y/UP/Z declare msg_r*k slot packing; U-K8 pads declare the UK8_B
    block grid. Slot capacity beyond the canonical padded grid stays a
    proving-layer obligation (junk-coordinate handling, unchanged).
- 2026-07-14 (orchestrator): P1 + P2 merged; ring_matmul.rs auto-merged
  (P1's verifier/h0 hunks and P2's statement-construction hunks were
  disjoint); merged-tree suite + batteries re-run before push.
