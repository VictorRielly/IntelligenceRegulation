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

- [ ] P2-D1 Typed integer semantics: raw encoding + scale-exponent
      conventions frozen in a typed spec; rescale scale propagation
      enforced even when a range proof narrows magnitude (C-03a);
      signed bounds asymmetric (or pos/neg checked separately).
- [ ] P2-D2 Typed TableSpec bound by exact metadata equality (digest,
      input/output quantization, domain) — not merely a nonzero digest.
- [ ] P2-D3 Statement v3 validation: acyclic topologically-ordered DAG,
      nonempty ops, orientation/role checks (LinkEqual per its own doc),
      output visibility, modulus capacity, canonical padding; bare
      ClaimManifest::digest() disabled outside migration tests.
- [ ] P2-D4 Ports: structured, lattice, ring, inventory, chain paths on
      the same statement type (the audit H-03 list: structured_matrix.rs
      3646-class and lattice_matmul.rs 3212/3516/3865-class call sites).
- [ ] P2-EXIT negative tests cover: inconsistent fraction bits, +2^(w-1),
      cycles, empty add, wrong table digest/scale, dangling roles,
      noncanonical padding.

## Phase 3 (opened by the orchestrator AFTER P1+P2 merge)

Canonical PublicStatement/ProverInput/Proof/VerificationError types;
serialization with lengths, versioning, canonical field encodings,
resource limits; verifier in a fresh process from statement bytes +
proof bytes + verified setup ONLY; fuzz/truncate/reorder every component
(errors, never panics); model digest from architecture + quantization/
table spec + all weight commitments.

## Log

- 2026-07-14: tranche opened; P1 + P2 agents launched in parallel.
