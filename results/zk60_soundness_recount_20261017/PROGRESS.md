# Soundness recount lane — ledger (2026-10-17 UTC)

Paper + one-thread Python only. No builds, no proofs, no git writes. Write set:
this directory only. Lane rules read: `ops/zkp-mvp/LANE_RULES_20261017.md`.

Object: register entry D15's per-opening figure 2^-106 = (3/4)^256 against the
ZK code actually used by every private-block commitment (RS(n + Q, nn), distance
1 - (n + Q)/nn), recounted per trained profile (TinyLlama T32/T64/T128 x 22
blocks, Llama-3-8B T32 x 32 blocks).

## Log

- 19:22 UTC — started; read lane rules, D15, obligations doc §4–5, token-I/O
  CHECK.md §3.3.
- 19:25 UTC — read `zkp-core/src/pcs.rs` (header :16-19 non-ZK delta; ZK section
  :555-583 RS(n+Q, nn); open_zk/verify_zk :1016-1160; indices sampled with
  replacement, `transcript.rs:136`), `hashline/src/zk.rs` mask commitment M
  (:373-375, :481-660: rows on 4096-point coset, prox tested against degree <
  1024, so delta = 3/4), `private_block/shape.rs` trained geometry (:345-378:
  log_cols 12/13/14 TinyLlama, 13 for 8B; inv_rate 4; endpoint defaults = block
  width and rate; COL_CHECKS 256 at :279), `protocol.rs` verify_core
  (:1174-1287: A, H, M opened once each per block), `run.rs` prove/verify
  (:884-960, :1060-1160: boundary B_k opened once in block k+1's segment; the
  two run endpoints once each).
- 19:28 UTC — found that the 125M twelve-block figure 2^-97.5 (D12a,
  MVP_STATUS) ALREADY used the real ZK distance (2^-105.61 at log_cols 14,
  `results/zk60_private_block_125m_check/recompute.py` §11). The figures built
  on (3/4)^256 are D15's own text and the token-I/O design's 192/132-opening
  stack term.
- 19:31 UTC — lane directory created; next: `recount.py` (layout formulas
  copied from the token-I/O mirror and cross-checked against the Rust-counted
  rows/lookups in `r3-ladder-count.log` and R4-1).
- 19:35 UTC — `recount.py` done (0.03 s, one thread): `recount.out.txt`,
  `recount.json`. Layout check vs Rust counts OK at all four registered
  profiles (A rows, H rows, U8 lookups). Per opening (real): 2^-103.69 (2^12),
  2^-104.97 (2^13), 2^-105.61 (2^14); M 2^-106.25 at every profile. Openings
  per run 4L + 1 (89 / 129), not 6L. Whole run (a)->(b), R14 LogUp 4N:
  T32 98.31->97.09, T64 97.52->97.23, T128 96.52->96.45, 8B T32 97.08->96.77;
  derived LogUp N: 99.25->97.42, 98.81->98.18, 98.12->97.94, 98.34->97.68.
  125M 2^-97.5 reproduced (already used the real distance). Restoring
  2^-106.25 per opening needs 263/260/258 checks (= pads) at 2^12/13/14,
  +0.3-1.9 % receipt bytes. Next: RECOUNT.md.
- 19:38 UTC — `RECOUNT.md` written (plain words, per-commitment tables, other
  terms, whole-run (a)/(b), the δ/3 cross-check, proposed dated note under
  D15, reproduction). Script extended with M's product check (2^-173.88) and
  the consistency half (2^-248 at 2^12). Lane complete; nothing running; no
  register edit (the note is a proposal for the coordinator / security owner).

## Task 2 — costed options memo for G.0-2 (coordinator, received ~19:39 UTC)

Object: private Llama-3-8B stack at T512 (speed plan's receipt-optimal row
width 2^15), whole-run targets ~96 / 100 / 110 / 128 bits; levers priced in
committed elements, receipt bytes, prover time [MODEL from the speed plan's
cost model]. Output `MEMO_G02.md` + `g02_levers.py`.

- 19:39 UTC — D15 correction note confirmed placed in the register by the
  coordinator (19:40 UTC).
- 19:40-19:43 UTC — read L4 memo §A, §C, §G (G.0 framing: per-opening vs
  whole-proof; δ/3 vs δ/2), obligations R14 (4N derivation: degree 2N-1 +
  2N pole avoidance), speed plan §1-§7, `cost_model.py`, `projection.py`
  (+ output). Haböck 2022 PDF fetch refused (HTTP 403); abstract page read
  (ePrint 2022/1530, "Multivariate lookups based on logarithmic derivatives").
- 19:44 UTC — copied `layout.py`, `cost_model.py`, `projection.py` verbatim
  into `g02_speedplan_copy/` (sha256 equal to the originals:
  abc5f58f..., 2460be8d..., a23d63c5...). Originals untouched.
- 19:45-19:50 UTC — `g02_levers.py` written and run (python3 -B, 0.25 s, one
  thread): baseline 8B T512 at 2^15 = 2^-94.66 derived / 2^-92.71 R14
  (LogUp-dominated: 2^-99.73 per block x 32; column 2^-98.99; PCS field
  2^-106.38; sumchecks 2^-112.19). Variant class reproduces the counted
  receipt / A / H rows exactly (asserted). Levers priced: derived bound (free,
  +1.95), LogUp repetition partial/full and Fp4 (+38..55 % committed, roofline
  57.3 -> 42.7..38.4), Q (+1.4 % receipt for +2.5 bits, 0 time), rate 1/8
  (roofline 36.7), two proximity vectors (+3.1 % receipt), all-Fp4 (roofline
  35.2, receipt +99 %), D1+Fp4 sketch (37.5-56.3). Target bundles ~96 / 97 /
  100 / 110 / 128 with kernel efficiency for 50/s 47.4 / 51.2 / 53.1 / 53.1 /
  58.2 % (today 34.5 %). Fp4 tower checked (-7 non-residue).
- 19:52 UTC — `MEMO_G02.md` written (plain words, baseline terms, levers with
  privacy/profile/review columns, target table, recommendation: MVP at today's
  ~95 whole-run (derived; 99.7 work-factor reading), 100 post-MVP via D1+Fp4
  or repetition, 128 product only; proposed G.0-2 wording). Task 2 complete;
  nothing running; no register edit.
