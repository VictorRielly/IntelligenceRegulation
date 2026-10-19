# PROGRESS — adversarial check of DD (per-row division dictionary)

Lane: paper + one-thread Python (< few s). No builds, proofs, git writes.
Write set: `results/zk60_gpt_nonlinear_review_20261018/dd_check/` only.
Proposal under check: REVIEW.md ROUND 2 §R2.4 (DD), `variants_r2.py`.
Deliverable: `CHECK.md` (verdict first, findings per point 1-4, draft
security-owner privacy note).

## Log (UTC from `date -u`)

- 2026-10-19 09:35 — started; read LANE_RULES_20261017.md and REVIEW.md
  ROUND 2. Next: native layout.rs / argument.rs / protocol.rs (R6 frozen
  tree), CHECK_LOGUP, decisions, trained privacy draft; then variants_r2.py.
- 2026-10-19 09:45 — read: layout.rs (P-3 lift, Dom, plane lists, lookups_at,
  slots), argument.rs (helper_sum, SC_RS, SC_SZC c0..c4 + cx, SC_TAB, SC_ZS,
  table_values_*), protocol.rs (logup_sum_claim, audit, prove_core order:
  A incl. multiplicities -> M -> beta, gamma, alpha -> H -> slots; CS-3
  refusal before A), check_logup/CHECK.md (B1/B2/B3 derivation),
  decisions D12, D15 notes, D16, D22, D24, D27-D29, the trained privacy
  draft §0-§3 and NL-1..NL-8, variants_r2.py + the speed-plan layout replica,
  B6_REPORT (e_s options), export e_s tallies (8B b7: 2/3/4; old 8B T32 has
  e_s 1 = n_E 32; TinyLlama e_s 1/2/3). Trained door admits e_s in [-8, 8],
  f_e in [9, 16]. Preliminary findings: (1) sound as proposed iff every
  dictionary position is constrained (no gate on k; pad rule for padded
  rows); LogUp bound gains a committed-table term (N + 2303 + 4*T_DD)/|F|,
  +0.39 bits instead of +0.40; (2) cap 32 fits current exports but not the
  trained class nor B6 candidate e_s 0 (n_E 55); e column must contain 0;
  (3) new refusal residual: zero table denominator now depends on hidden
  Sums (~2^-109/block); (4) count: variants_r2 omits the new DD slot's
  18 claim sites (36 rows) -> -20.8%, not -21.0%. Next: dd_check.py
  (census, independent count, toy LogUp counterexamples), then CHECK.md.
- 2026-10-19 09:47 — `dd_check.py` written and run (one thread, < 1 s;
  `dd_check.out.txt`, `dd_check.json`; -I -B, no pycache). Independent count
  reproduces today's 663,257,088 / N 323,026,944; DD cap 32 = 525.2 M
  (-20.82%) with the DD slot's sites, 524.0 M (-21.00%) without (=
  variants_r2); cap 64 -18.92%. LogUp (N + 2303 + 4 T_DD)/|F|: 2^-100.12 per
  block (+0.39 bits), 2^-95.12 per 32-block run. Refusal residual 2^-103.0
  two-world per run (today 2^-112.4). Toy: honest 20/20; bad P 0/20; gated
  padding slot 20/20 PASS (hole if gated); no key 20/20 PASS; m after alpha
  20/20 PASS; Sum-keyed sound. Census: 116/272 class members fit cap 32;
  8B b7 19/11/6, old T32 e_s 1 = 32 (full), TinyLlama 24/14/8, B6 e_s 0 = 55.
- 2026-10-19 09:52 — DONE. `CHECK.md` written: verdict (sound as proposed iff
  every dictionary position constrained; bit-exact; +0.39 bits; privacy holds
  linearly/algebraically with one new refusal residual needing an owner
  ruling; cap must count {0} u outputs and cover all layers; -20.8%; ready to
  be SPECIFIED with B-1..B-8), per-point findings, LogUp re-derivation,
  recount table, draft owner privacy note (§6), binding list (§7). Nothing
  running; nothing outside this directory written.
