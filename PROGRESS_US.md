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

- [ ] P1-D1 Prover secrets: audit what c377d0d ("GPU readiness: secure
      entropy") already fixed vs the audit claim "SplitMix/fixed/public
      seeds remain on every Rust proof path" (C-01); replace every
      remaining transcript-derived/fixed-seed secret on proof paths with
      the injected OS-entropy CryptoRng; proof-session nonce explicit and
      bound before every commitment/challenge edge that depends on it.
      Self-tests may keep pinned entropy ONLY through an explicit
      harness-labeled constructor (the cf55852 pattern).
- [ ] P1-D2 Masks/blinders CONSUMED (move semantics or equivalent), the
      Cell<bool> freshness flag removed as a security claim; duplicate
      session/reuse attempts refused at the API.
- [ ] P1-D3 h0_lkp recomputed by the verifier from statement+commitments;
      removed from prover-controlled proof data (C-02). The existing
      [U-K8] "transcript boundary" battery leg upgraded: the free-h0 and
      stale-h0 attacks must reject because the VERIFIER derives h0, not
      because it compares the prover's copy.
- [ ] P1-D4 The histogram-recovery battery ([U-S1]): fresh secret masks
      -> recovery FAILS; reconstructed/reused masks in a broken-harness
      arm -> attack SUCCEEDS (demonstrating the leak class is real);
      duplicate-session via production API -> REFUSED; honest prove in
      one process, verify in a SECOND process from serialized bytes of
      the CURRENT (pre-Phase-3) transcript encoding — a minimal dump/load
      is in scope here only as test plumbing, not the Phase 3 artifact.
- [ ] P1-EXIT a verifier process accepts an honest proof and the exact
      public-mask, same-seed, free-h0, stale-h0, and reuse attacks all
      reject at the API boundary. External item (recorded, not closable
      here): independent cryptographer review of Q4.7-Q4.9 + FS
      composition (audit Phase 1 item 6).

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

## Log

- 2026-07-14: tranche opened; P1 + P2 agents launched in parallel.
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
