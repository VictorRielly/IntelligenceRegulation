# Gaps GS-4, GS-5, GS-11, GS-12 of the shaped generic-rank lemma — disposition

By the interactive Claude session acting as security owner (Opus 5.5,
continuing the Fable 5.1 lane), 2026-09-23, 13:05 PDT. It rules on
`ZK60_GS4_GS5_GS11_GS12_CLOSURES.md` (a delegated agent's draft, `23207cd`)
after `ZK60_GS4_GS5_GS11_GS12_CLOSURES_CHECK.md` (an independent agent told
to break it; own code, exact-geometry brute force at rung-G; `df9f5f5`). The
gaps are defined at `ZK60_GENERIC_RANK_LEMMA_SHAPED.md:1370-1378`; they are
obligation 5 of `ZK60_SHAPED_PRIVACY_PATH_STATUS.md`.

**Not a privacy acceptance of anything.** D22 (the toy) is untouched.

## 1. Verdicts

| Gap | Verdict | Evidence |
|---|---|---|
| **GS-4** audit exclusivity at 125M | **CLOSED** (observed) | the checker's own code on all 30 captured views (22 at 125M, 8 at rung-G): pairs disjoint, every reserved row covered once, the pair-basis condition — 0 failures. The draft's evidence was overstated (F-4, F-5, below) |
| **GS-5** `disclosed = n·k0 + u*` at n ≠ Q | **CLOSED, as corrected** | steps 1, 2(b), 3 re-derived; exact on all 424 of 532 brute-force instances outside one family, incl. n = Q, n < Q up to 3n, odd n, the real A/H group sizes, the real endpoint/boundary row counts, and the rung-G endpoint at its REAL geometry (9 rows, n 1,024, Q 256): 0 = formula. 125M's own geometry (~10^8 unknowns) was not brute-forced |
| **GS-11** M-q / M-prox | **CLOSED** (carry-over confirmed) | M's geometry is shape-independent in code and on captures; the shape enters only through the mask lengths (583 / 859 / 1,239, worst 117 of 256); F-9 corrects one statement |
| **GS-12** activation lookups at padded positions | **CLOSED** | act[128] = 0 re-measured on the captures; S38-F1(a) with CS-1/CS-9 refuses any statement where the padded pair (128, 0) is not a row; "vacuous at 125M" is right for the activation family (F-11 wording) |

## 2. The counterexample, and why it cannot occur (ruling GC-1)

The checker found a family where the formula under-counts by one Fp
dimension (108 of 108 instances): a **dependent proximity pair** together with
a multi-member group whose column weights are Fp-collinear. It then PROVED the
corrected statement: the proximity term drops out if some multi-member group's
weights are not Fp-collinear with β ≠ 0, or some non-pair reserved row is
touched by ρ_prox. **I read `protocol.rs:305-310` on the lane: a proximity
pair with zero determinant is refused ("dependent proximity mask
coefficients; discard attempt"), as is any zero group coefficient
(`:296-301`)** — challenge-only refusals, priced as liveness in D20's
accounting. So the counterexample family needs a view the protocol never
emits. **Ruling GC-1:** GS-5 is closed with the formula's hypothesis stated
explicitly — the proximity pair independent, enforced at `protocol.rs:306` —
and the lemma's text cites that refusal as the reason. No capture has an
Fp-collinear multi-member group either (checked, not relied on).

## 3. Gate fixes (ruling GC-2 — the next gate round)

- **F-3:** compute the u-term EXACTLY as `rank Γ_{D∪N'} − rank Γ_{N'} − k0`;
  the gate's current term under-counts on 36 of 36 constructed cases (the
  drafter's proposed fourth hypothesis is implied at every present shape and
  not needed once the term is exact).
- **F-4:** the gate's H-pair check accepts OVERLAPPING pairs, so it is not the
  same observation as `audit_claims`; make it refuse overlap (a control that
  overlaps two pairs must fire).
- **F-6:** the 26 negative controls are only 7 kinds; add controls so that
  every clause of exclusivity is exercised at least once.
- Record every re-taken record with 0 unexpected leaves, as rounds 9i–9k did.

## 4. Errata to the draft (dated block at its top)

F-5 (the replay's 22/22 holds by construction — captures are written after
`check_opening` passes; the observation is the checker's, not the replay's);
F-9 (the mask fit is ruling C-4's refusal in `shape.rs`, not only an assert);
F-11 (CS-3 guarantees the padded pair is SOME table row; that it is row 128
with value 0 is S38-F1(a)'s refusal); F-7 (the run captures are from
`f4697f9`; the audit code is unchanged since); F-12/F-13 (six other domains
pad at 125M, and `A_E` is exempt from the pad rule — none of them is the
activation family).

## 5. What this changes

Obligation 5 of the status page shrinks to: the LAW of the blinding for G-R4
(NL-8) and the gate fixes GC-2. The generic-rank lemma at the shaped layouts
has no named residual left but those.

## 6. GC-2 done (2026-09-23 15:52)

Gate round 9l (`zk60-native-jointview` at `7fb276e`, ledger §R9l):
- **F-3, the exact u-term:** predicted from the committed records that no
  value would move (241 u-term entries in 41 records, every zero-sum
  indicator reachable, so the old term equals the exact one there); none
  moved — 160 entries in 32 records carry both terms and agree, 125M
  included (`H@0` 2 = 2, block joint 2 = sum 2). On the check's 12
  constructed `U-adm` cases a brute force of the whole view reads
  `n·k0 + u*`; the exact term matches through both code paths, the old term
  reads `u* − 1`.
- **F-4 / F-6, exclusivity:** 16 named clauses EX-1…EX-16, each with its Rust
  source line (`scripts/zk60_native_rg_exclusivity.py`: pairs disjoint,
  every reserved row used, even offset, pair basis, sum claim, group count,
  endpoint shape, …); 24 controls on a run, 23 on a block; every record
  exercises all 16; 764 controls fire and none on an honest view; all 272
  honest commitments pass 16 of 16, incl. A, H and both endpoints at 125M.
  The overlap control X10a is refused by the new check; the old check
  accepted it and 6 of the other 22.
- 30 records re-taken + two new cheap 125M block records, 0 unexpected
  leaves; suite 660, toy 217, guard 42.

**Open, small:** the TOY gate (D22's evidence) still has the old pair check.
D22 does not rest on the gate's pair check — the verifier's own
`audit_claims` enforces exclusivity on every accepted receipt, and the toy
statement cites the argument, not this observation — but the toy gate
should observe exclusivity with the same 16 clauses; it is hash-pinned by
the record guard, so porting EX-1…EX-16 into it is a deliberate re-pin in a
later round.
