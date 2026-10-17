# Independent check of the private block's LogUp bound — ledger (2026-10-17 UTC)

Checker lane (paper + one-thread Python, no builds, no proofs, no git writes).
Write set: this directory only. Lane rules read: `ops/zkp-mvp/LANE_RULES_20261017.md`.

Claim under check: `../MEMO_G02.md` §3.1 and `../RECOUNT.md` §3 — the private
block's LogUp error is (N + 2303)/|F| per block (N = looked-up entries,
|F| = |Fp2| ~ 2^128), not R14's 4N/|F|.

## Log

- ~19:56 UTC (start; before the first `date -u` read) — read lane rules, MEMO_G02,
  RECOUNT, the recount lane's PROGRESS, obligations doc R12-R14 (:120-144) and
  §4.3-4.6, §5-§6.
- 19:56-20:00 UTC — read the native code (read only): `layout.rs` (Dom::Tab lift
  :110-188, multiplicity planes :284-310, H planes :440-585, lookup lists
  :588-797, slot kinds :880-905), `argument.rs` (Ctx :126-136, LkT/helper_sum
  :869-910, table values :1076-1105, SC_TAB :1860-1909, SC_ZS :1910-1919, exp
  helper :1837, act helper :1642), `protocol.rs` (header :96-127, logup_sum_claim
  :164-182, finish_claims :313-318, prove order :900-1106, verify order
  :1199-1262), `shape.rs` (domain logs/sizes :1735-1777, lookups per position
  :1803-1826, slot schedule :1901-1940, trained geometry :345-378),
  `zkp-core/src/transcript.rs:113-133` (128-bit draws mod p),
  `zkp-core/src/pcs.rs:815-990` (ZK sum claims), `tables_attn.rs` tags
  (EXP 129, U8 133, ACT 134).
- 20:00 UTC — lane directory created. Next: `check_logup.py` (N per profile from
  the shape formulas, cross-checked against the Rust counts; the three bounds;
  the helper zero-check term), then CHECK.md.
- 20:01-20:04 UTC — `check_logup.py` written and run (python3 -B, one thread,
  < 0.1 s; output `check_logup.out.txt`, `check_logup.json`). U8 counts equal the
  Rust counts at all five Rust-counted geometries; N, the R14 and the derived
  figures equal the recount lane's at all four registered profiles and the memo's
  8B T512 (2^15) figures. Finding: the memo's item 4 ("query-side poles are not
  a soundness term") is wrong for PAIRED helpers — when both members of a pair
  equal alpha, h(a-f)(a-f) = 2(a-f) reads 0 = 0 and h is free. The bound
  (N + 2303)/|F| still holds because the number of distinct query values plus
  the number of such pair values is at most N (each pair value is hit twice).
  An explicit strategy (equal norm-remainder limb pairs, plus the sigma_s limb
  pairs at three limbs) reaches |PP| = 8|D| (+2|S|): a LOWER bound 2^-103.0 per
  block at 8B T512 against the derived 2^-99.73, so the bound is within ~3.3-3.9
  bits of tight at every profile. Helper/table/zero-sum zero-checks: 2^-117.5
  per block (inside the recount's sumcheck term). Next: CHECK.md.
- 20:07 UTC — `CHECK.md` written (verdict, implemented variant with file:line,
  derivation B1/B2/B3 + counting step, lower-bound strategy, helper zero-check
  term, R14 reading, per-profile table, holes table, three wording corrections,
  two flagged remarks: cross-block composition and Fiat-Shamir). Verdict:
  (N + 2303)/|F| CORRECT as an upper bound (item 4's reasoning wrong, total
  survives); R14 a valid upper bound 2.00 bits looser; no hole found. Lane
  complete; nothing running; no git write; no register edit.
