# The adversarial testing plan — SHELVED until the working PoC

Status: DOCUMENTED AND SHELVED (Victor, console 2026-08-30: "we will
try to push it to its limits to see if we can find exploits... For
now we should document this testing plan and shelve it. It is more
important to reach the working proof of concept.") Nothing in this
file is scheduled; it activates by ruling once the 8B FFN PoC proof
has run end to end.

## 0. What we already have (the baseline the campaign starts from)

Do not restart from zero: the per-component tamper batteries are the
existing adversarial floor, all green on both architectures —
diff-battery E2E legs, the uperf-s 48-leg + agg 136-leg batteries
(tampered claims/rounds/masks reject), the uperf-v3 tamper arms
(WrongWeight, WrongTable, SeamSwap, RangeViolation, LimbForge,
RoundModeLie), lane FF's malicious-prover refolds, lane GG's
pass-level mask tampers, the X-S1 8-leg attention battery with
pre-registered gates, and the python<->Rust cross-language
reconciles (128 + 192 plane legs). These are HONESTY tests around
designed failure modes; the campaign below is about UNDESIGNED ones.

## 1. Attack surfaces, ranked by expected yield

1. **Statement-semantics gaps** (what the statement PROVES vs what a
   reader assumes it proves): the clamp-at-z relation (can an
   adversarial witness abuse unlimited clamping to encode a
   different computation while every fact holds?); accept-bounds
   (the two-sided vs one-sided range reading — OQ-2 — is EXACTLY
   this class, already flagged); the margin exponents (a malicious
   exporter choosing pathological-but-legal margins); the C4
   qualification gate gamed by adversarial calibration data.
2. **Fiat-Shamir discipline**: a transcript-order audit (every
   absorb before every draw it influences — the lane-GG act-h
   mid-transcript group is a fresh seam to audit); domain
   separation between instances/groups/waves; replay/mix-and-match
   across proofs sharing a preprocessed weight commitment (the
   amortization posture ADDS this surface: binding act proofs to
   the weight commitment instance).
3. **Soundness-parameter margins**: the LS18 invertibility margins
   (measured 1.30x — how adversarially tight?); the K9 packed-table
   cap's audited bound; the exact-digit gate headrooms at the 8B
   tier splits (FF's counted rows); challenge-space sizes vs the
   claimed soundness bits — a single consolidated soundness budget
   document with every term, none of which currently exists in one
   place.
4. **The masking/ZK claim**: statistical distinguishers on masked
   transcripts (the O-4 masks blind — measured by inspection, never
   by a distinguisher battery); leakage through REJECTED proofs;
   the mask-commitment binding under adversarial mask choices.
5. **Implementation drift**: the duplicated-constant discipline
   (lookup.rs vs manifest.rs) under adversarial edit; the CRS
   stream's resumable-prefix table (KK's spec correction — audit
   the resume path); unchecked arithmetic on adversarial sidecar
   values (the bf_model parser fuzz); the aarch64/x86 byte-identity
   as a standing differential (the Mac sync found real cfg gaps).
6. **Fuzzing at scale**: randomized witness/transcript/sidecar
   mutation with accept-rate zero expected — cheap CPU-night work,
   millions of mutations, every accept is a finding.

## 2. Campaign structure (when activated)

- Phase A (1-2 weeks): the soundness budget document (surface 3) +
  the FS transcript audit (surface 2) — paper first, because a gap
  found on paper is cheaper than one found by fuzzing.
- Phase B: the statement-semantics red team (surface 1) — one agent
  lane per question, each with a "construct a witness that accepts
  but lies" brief; a constructed exploit is the deliverable, not an
  opinion.
- Phase C: the fuzz battery (surface 6) as standing infrastructure
  (nightly, flock-queued) + the mask distinguisher battery
  (surface 4).
- Phase D: external eyes — the codex-audit-* pattern exists in the
  repo as precedent; a second external pass over the frozen
  statement + the soundness budget.
- Exit criterion: every surface has either a green battery, a
  documented accepted-risk row, or a fix — no silent categories.

## 3. Standing rule adopted NOW (cheap, not shelved)

Every new statement feature from this point (the weight-
preprocessing binding, X1's entry classes, the range-only freeze
set) ships with its tamper legs AT THE SAME COMMIT — the existing
discipline, stated as a rule so the shelved campaign inherits a
floor that never regressed.
