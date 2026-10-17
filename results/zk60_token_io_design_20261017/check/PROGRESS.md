# Token I/O design — adversarial check, ledger (2026-10-17)

Lane: ADVERSARIAL CHECKER of `../DESIGN.md` (token I/O design). Paper only:
no builds, no proofs, no git writes; Python only one-thread arithmetic under
a few seconds. Exclusive write set: this directory (`check/`).
Deliverable: `CHECK.md` here.

## Log (UTC from `date -u`)

- 2026-10-17T19:00:23Z — check dir created; read LANE_RULES_20261017.md,
  DESIGN.md, design PROGRESS.md.
- 2026-10-17T19:15:15Z — read token_io_count.py, layout.py (replica), DECISIONS
  (D7-D24 entries), PRIVACY_REQUIREMENTS, protocol.rs (whole), argument.rs
  (slot machinery, matmul/host/zero-check arms), layout.rs (P-3 lift, stage-23
  invariant), run.rs (header, stage order, boundary/endpoint openings),
  boundary.rs (M-1 / M-7), endpoint_g.rs, zkp-core pcs.rs (ZK code is
  RS(n+Q, n*inv_rate); salts 32 B per column). NOTE: ran the design's counter
  once piped into `head` from /tmp; it writes `../token_io_count.json` only at
  the end of main() and the file's mtime/size are unchanged (11:51 PDT,
  108229 B) — no write happened. All further runs use my own script in check/.
  Candidate findings so far: (1) hidden selector unbound to P (soundness of the
  intended statement); (2) token endpoints at 256-wide rows, Q=256 pads, rate
  1/4 give per-opening (5/6)^256 = 2^-67 (design counts 2^-106); small stage
  widths 2^10/2^11 lose 10/5 bits per opening; (3) pin lookup in (A4) is
  unnecessary for soundness (2^48 + 2^44 < p); (4) IO slot / lift domain
  specification gaps (tok vs h_q domain, 256-word token plane pads unbound).
- 2026-10-17T19:17Z — wrote `check_arith.py` (independent, imports nothing from
  `../`): no-wrap clauses both models, randomised exhaustive keyed-argmax check
  (1,200 cases, 0 mismatches, with and without pin), committed elements
  re-derived (8B T32 mode i 3,057,664; 8B T512 mode ii U8 1,066,008,576, U16
  595,525,632 — all match the design), per-opening proximity terms with the ZK
  code RS(n+Q, n*rate) and whole-proof totals (design geometry 2^-66.3; repaired
  2^-98.5 / 2^-98.9). Output `check_arith.json`, `check_arith.out.txt`.
- 2026-10-17T19:21:11Z — `CHECK.md` written: verdict (safe for R0 now, R1 after
  binding changes B-1 token endpoints rate 1/8 + stage widths >= 2^12, B-2 seal the
  hidden selector under an endpoint root, B-3 slot-cube specification), findings
  F-1..F-9, points P-1..P-5, rulings surfaced (R2 amend, R9 earlier, per-opening
  counting convention under D15, D19b dependency). Verified `../token_io_count.json`
  and `../__pycache__` untouched.

## State after pass 1: DONE. Nothing running, nothing launched.

## Pass 2 (coordinator request: DESIGN v2 C-1..C-12, §8 R9, rung R0)

- 2026-10-17T19:38:14Z — pass 2 opened. Inputs: DESIGN.md v2 (980 lines, 12:37 PDT),
  token_io_count.py v2, r0/ (token_io_ref.py, token_io_vectors.py, vectors.json,
  test_token_io_ref.py), D25 / D23 / D19b in ZK60_DECISIONS.md. Deliverable
  `CHECK2.md`. Rule: never run anything that writes outside check/ (the design's
  counter and vector generator write into ../; run copies or read-only).
- 2026-10-17T19:45:45Z — read DESIGN v2 (§0, 2.3, 3.1-3.3, 4, 6.4, 7, 8), counter diff
  v1->v2, r0/ (ref, vectors, tests), D25, zk.rs mask commitment (RS(1024,4096), 3/4).
  Ran R0's suite with `python3 -B` from /tmp: 13 pass, no bytecode written (r0/ and
  the calibration dir's __pycache__ unchanged). Wrote `check2_probes.py` (imports R0
  read-only, -B) -> `check2_probes.json`: T1 A6-only and T2 e-pad-zero-only forgeries
  rejected by R0 but absent from its vectors; T4 BOS clause written unweighted accepts
  tok_0 = BOS+1 with h_q(0) = 0 (fresh coefficient rejects); T5 final-norm forgeries
  rejected (no vectors); T6 s (2,-1) caught only by booleanity; T7/T8/T9 sealed-right
  used-wrong / re-lookup / other output id pass every R0 relation and the owner check
  (R0 has no IO-in / IO-s / IO-out relation). Also: BOS id 1 is TinyLlama's only
  (Llama-3-8B 128000); the design's note that each block's M is 2^-96.1 is wrong
  (zk.rs: RS(1024, 4096), distance 3/4, 2^-106.25); hidden-length A_out sites 50 not 49.
- 2026-10-17T19:47:39Z — `CHECK2.md` written: B-1..B-3 closed; pin drop safe; new hole
  N-1 (BOS clause unweighted; fix = fresh coefficient) + N-2 (BOS id per profile);
  R9 variant P sound and private, recommend accept with conditions C-a..C-e (variant
  bound in statement, verifier-enforced deferred single opening, own spec/digest domain,
  owner check on derived geometry, G-6/G-7 gate); R0 test gaps N-10..N-14 (A6-only,
  e-pad-only, A3, final-norm forgeries, s not one-hot, no IO-in/IO-s/IO-out relation);
  recommended R9 ruling text in §4. Nothing running.

## State after pass 2: DONE. Nothing running, nothing launched.
