# Token I/O design lane — ledger (2026-10-17)

Lane: TOKEN I/O DESIGN. Paper only: design, counted costs, test-first plan.
No builds, no proofs, no git writes. Exclusive write set: this directory.
Deliverable: `DESIGN.md` here. Counting scripts here (one thread, < 1 s).

## Log (UTC from `date -u`)

- 2026-10-17T18:35:51Z — lane dir created; read `ops/zkp-mvp/LANE_RULES_20261017.md`.
- 2026-10-17T18:46:57Z — read: CLAUDE.md (in context), ZK60_PRIVACY_REQUIREMENTS.md,
  ZK60_DECISIONS.md (D7, D8, D11, D12, D12a, D12b, D13, D16, D17, D18, D21, D22, D23, D24),
  TOKEN_IO_SPEC.md, layout.py / cost_model.py / projection.py (speed plan),
  private_block/layout.rs (planes, lookups, slots, P-3 lift), argument.rs (slot
  machinery: matmul slots fold the PUBLIC weights on BOTH sides, `Tab::Pub` is
  materialised and MLE-evaluated by the verifier, `b.supp` is a full-cube table),
  run.rs (stage order, boundaries, external endpoints), boundary.rs (rows =
  data + 2*sites + 2), endpoint_g.rs (5 mask rows, one site), protocol.rs
  (A -> M -> beta,gamma,alpha -> H -> slots -> openings; tuple lookups compressed
  with beta and table tags), tlcalib.py (weights: per-TENSOR scale, int8 clipped
  to +-127), private-model-kernel (zkVM token semantics: last row, raw i64 logits,
  lowest-index argmax).
  Design direction fixed: input = compressed-row indexed LogUp (tuple
  (tok, x~(t, r_emb)) into the V-row table (v, E~(v, r_emb))); output = stage OUT
  (final norm + head matmul + keyed argmax with one-hot selector); both as new
  run STAGES joined to the blocks by ordinary D12a boundaries.

- 2026-10-17T18:55:31Z — copied `layout.py` and `cost_model.py` (unchanged) from the
  speed plan; wrote `token_io_count.py` (stage counter: input options a/b/c, output
  stage modes i/ii, U8/U16 limbs, keyed/step tie rule, receipt-optimal row width per
  stage, run totals vs the stack). Ran it (one thread, < 1 s): output in
  `token_io_count.json`; console tables reproduced in DESIGN.md. Headline:
  input (b) 0.12 M (Tiny) / 0.44 M (8B) committed elements at every T; output
  mode (i) 0.82 M / 2.62 M; 8B mode (i) total +3.18 s laptop CPU [MODEL] (+3.0 % at
  T32), verifier +1.63 s (two 537 M-entry public folds). Mode (ii) U8 at 8B T512:
  1.066 G elements (+5.0 %), VZC slot tables 16 GiB. Citations checked: LogUp
  ePrint 2022/1530 (research lane sources), Twist and Shout ePrint 2025/105
  (CRYPTO 2026, web), zkLLM arXiv 2404.16109 (web).

- 2026-10-17T18:58:53Z — DESIGN.md written (sections 1-7 + appendix). Chosen:
  input option (b) compressed-row indexed LogUp; output stage OUT = final norm
  (uniform gain, block norm_a relation, D24 tn) + head matmul (virtual raw-int
  logits) + keyed argmax (one-hot e, 6 byte limbs + pin, window 41/44 bits);
  mode (i) next token first, mode (ii) whole greedy continuation later.
  Nine rulings listed (R1-R9). No job launched; nothing pending.

- 2026-10-17T19:22:20Z — coordinator: adversarial check landed (`check/CHECK.md`): core holds;
  binding B-1 (token endpoints 2^8 rate 1/8, stage widths >= 2^12, real ZK-code distance),
  B-2 (seal the hidden selector under an endpoint root), B-3 (tok on lifted domain, IO slots over
  whole endpoint plane, public factors on RSEL); recommendations F-4..F-9. Tasks: fold into
  DESIGN + counter (dated changes), amend R2 / move R9, then rung R0 (Python reference, no proof).
- 2026-10-17T19:24:09Z — kept v1 as `token_io_count_v1.py` / `token_io_count_v1.json`.
- 2026-10-17T19:26:08Z — `token_io_count.py` v2 written and run (< 1 s): per-opening terms,
  endpoint objects (one / two sites), width floor 2^12, no pin, selector variants (input-sealed,
  output-sealed). Reproduces the check exactly: 8B T32 mode (i) 2,830,336 elements, whole-proof
  commitment term 2^-98.47 (8B) / 2^-98.93 (Tiny), v1 geometry 2^-66.34, 8B T512 mode (ii) U8
  931.66 M. Fidelity lane read (s4_head.py): head = my section 3 form, g0 127, tn 10, profile
  Ceps, Cn from norm_site(c = 1, margin 0.5), also sweeps the refusal-free Cn = 2^tn; its s4 is
  queued behind the privacy gate job (~20:30 UTC); REPORT.md not yet written.

- 2026-10-17T19:31:34Z — DESIGN.md v2 written: section 0 (dated changes C-1..C-12), all
  numbers from counter v2, B-1..B-3 folded in, F-4/F-5/F-6/F-8/F-9 adopted, F-7 decided
  (fidelity numbers choose: refusal-free Cn if it meets D25 T4's 99 %, else D20 listing).
  Coordinator relayed Victor's 19:28 UTC acceptance: R1-R8 = D25 T1-T8 (D23, D19b also
  accepted). Section 7 now records them as ruled; R9 written as its own proposal (section 8:
  variants P / F / C, geometry 7 / 7 / 10 rows at T32 / T128 / T512, privacy and soundness
  accounting, draft ruling text); R10 (per-opening convention) kept open. BOS term added.

- 2026-10-17T19:37:11Z — rung R0 landed under `r0/`: `token_io_ref.py` (integer semantics,
  relation checkers over Goldilocks, owner-side seal with a SHA-256 stand-in commitment, causal
  stand-in stack), `token_io_vectors.py` -> `vectors.json` (V = 300 / d16 / T8 synthetic model,
  12 vectors V01..V12: honest public row and hidden length, ties, non-maximal, non-one-hot,
  wrong row / word, histogram, out-of-vocab, BOS, F-1 attack, final-norm overflow, limb), and
  `test_token_io_ref.py` (13 tests, all OK in < 1 s, incl. a cross-check of `final_norm` against
  `tlcalib.i_norm` at width 2048 — no bytecode written into the calibration tree). DESIGN 6.4
  filled; section 3.2 site counts corrected (47 / 49 on A_out). Fidelity REPORT.md not yet
  landed (its s4 queued to ~20:30 UTC); R0 uses its head definition read from `s4_head.py`.

- 2026-10-17T19:51:19Z — coordinator: second check `check/CHECK2.md` (probes `check2_probes.py`):
  B-1..B-3 closed, pin drop safe; NEW hole N-1 (BOS clause unweighted in the query zero-check:
  tok_0 = BOS+1 with h_q(0) = 0 drops position 0 from the LogUp), N-2 (BOS id per profile: 1 /
  128000), N-3 (fresh challenge per batched clause), N-7 (hidden-length A_out sites), N-8 (wrong M
  clause), N-10..N-14 (R0 test gaps). R9 ruled as D26 (19:50 UTC: variant P, F fallback, C not
  adopted, C-a..C-e binding). D15 corrected 19:40 UTC (RECOUNT: stack commitment term 8B T32
  2^-98.19, Tiny T32 2^-97.55; 4L+1 openings). Tasks: DESIGN v3 + counter, R0 vectors/tests for
  N-10..N-14 and N-1, R1 control list.

- 2026-10-17T19:58:33Z — v3 done. Counter v3: stack term per RECOUNT (3L+1 at real distance +
  L masks at 2^-106.25; reproduces 2^-98.19 / 2^-97.55 / 2^-99.27), token-I/O deltas, whole run
  (R14) from RECOUNT where it exists (8B T32 2^-96.77 -> 2^-96.71; Tiny T32 2^-97.09 -> 2^-97.02;
  Tiny T128 2^-96.45 -> 2^-96.41); N-7 selector sites 4 (A_out 50; 8B 345 rows, 2.380 M).
  R0 v3: BOS per profile (1 / 128000, class check), check_argmax skip, helper-level stage-IN
  model (fresh mu_bos vs v2 unweighted), field final-norm checker with explicit windows + x int16,
  IO relations; vectors V13..V24 (V15 sharpened: A3-only forgery shifts M by 2^-v (tok'-j));
  20 tests OK in 0.7 s. DESIGN v3: section 0 (V3-1..V3-9), BOS clause with own coefficient and
  per-profile id (2.3, 7.1), batching rule + load-bearing note (3.1), sites (3.2, 3.5, 8.5),
  4.4 rewritten on RECOUNT (M clause deleted), R1 control table with 23 rows (6.1), 6.4 R0 v3,
  7.2 (R9 = D26, R10 answered by the D15 correction), 8 cites D26 + 8.7 conditions C-a..C-e.
  Did not run `check/check2_probes.py` (it writes under check/, another lane's set).
  Fidelity REPORT.md still not landed.

- 2026-10-18T04:25:29Z — coordinator: three implementation notes for v4 (TF-1 derived limbs; TR-7
  block shape's key set; TF-6 receipt = the code's counted lengths), record R1/R2 built+reviewed and
  R3 counted, rerun counter + R0 tests. Read: review verdicts (REVIEW.md round 1: sound, TR-1 MEDIUM
  / TR-2 LOW-MEDIUM fixed; REVIEW2.md: no HIGH/MEDIUM), the rung ledger/REPORT (R2 255,258,816 B,
  R3 471,285,072 B, 137 openings, floor 97), the codec (`token_io.rs::StageSegGeom::len`,
  `wire.rs::segment_len`, stage A/H groups 3/4 and 18/6), fidelity REPORT.md (per-tensor 98.45 %,
  per-row 98.91 %; D25 T4 amended 20:21 UTC option (b): 12-bit multipliers, margin criterion), D27.
- 2026-10-18T04:31:39Z — counter v4 (v3 kept as `token_io_count_v3.py/.json`): per-row logit bound
  (2^12), derived limbs (7 at TinyLlama 53 b / 8B 56 b), stage framing 88+32(+32 B_in root), IO-in over
  d_pad, TZC 1 round, A/H groups 3/4 and 18/6, stage OUT closes B_out (2 groups, data+6 rows), block
  segment in a run = single-block estimate + 112 B with the boundary opening; `check_code_lengths()`
  asserted in main(): R2 and R3 stage IN / block / stage OUT / total all EQUAL the code's lengths.
  Finding: U16 limbs inadmissible under the 12-bit class (4 x 16 = 64 bits; 2^64 + 2^53 >= p) — the
  counter marks those variants, DESIGN withdraws the (U16) alternative. R0: `keyed_window_bits`,
  `limbs_for` (+ no-wrap flag) and a TF-1 test; 21 tests OK in 0.5 s; vectors.json byte-identical.
- 2026-10-18T04:35:43Z — DESIGN v4: section 0 (V4-1..V4-8), summary numbers, 3.1 (per-row head with
  multipliers, derived L, Cn outcome, U16 withdrawn, R adopted), 3.2 sites 49/52, 3.5 tables (= code
  receipts), 4.1 D17 bullet (TR-7), 4.4 rows N-1..N-3 + the built statements' 97-bit floors / D27,
  5 tables, 6.1 rung status, 6.3 F1 done, 6.4 R0 v4, NEW 6.5 (R1/R2/R3 record), 7.1 R4 amended + D27
  note, appendix. Stray __pycache__ dirs removed. Nothing launched; nothing running.

## State: DONE for this round (DESIGN v4 + counter v4 + R0 v4). Nothing running.
Open follow-ups: R3's independent review (not reported to this lane); the hidden-length variant,
mode (ii) and the G-1..G-7 gate tooling are unbuilt.
Open follow-up: when the fidelity lane's REPORT.md lands, record its Cn choice (calibrated vs
refusal-free) against D25 T4 in DESIGN C-7 and section 3.1 item 2.

Successor notes: the counts are a design replica, not code; when stage IN/OUT
are built, the first test of each rung should assert the code's counted layout
equals `token_io_count.py` (rows, sites, receipt bytes), as `layout.py` does for
blocks. The receipt estimate's column-group counts are approximations.
