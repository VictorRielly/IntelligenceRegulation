# Independent adversarial privacy review — trained TinyLlama T32 draft

Lane: independent adversarial privacy reviewer (delegated Claude Opus 5.5 agent).
Object: `results/zk60_gate_tinyllama_20261017/PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md`
(round 3 revision), the gate port `ops/zkp-mvp/gate-tinyllama/` (v4), the
gate evidence in `results/zk60_gate_tinyllama_20261017/`.
Mode: PAPER ONLY plus one-thread Python of a few seconds. No builds, no
proofs, no git writes. Write set: this directory only.
Output: `REVIEW.md` here. Not an acceptance.

## Log (UTC from `date -u`)

- 21:06 — lane opened; read LANE_RULES_20261017.md, ZK60_PRIVACY_REQUIREMENTS.md,
  the draft (581 lines). Next: register rows, toy statement, the three
  argument documents and their dispositions, then the port.
- 21:09 — read register rows (D8/D11, D12, D9, D12a/b, D19-D27), the toy
  statement (D22), the dispositions of the shaped rank lemma, GS-4/5/11/12,
  the run joint law (R-1..R-7), the run hash layer (H-1..H-8), the shaped
  refusal census (CS-1..CS-9). Launched three read-only helper agents
  (no builds, scratchpad only): (1) port attack on gate v4 incl.
  `zk60_native_rg_status.py` ARMS-ONLY; (2) Rust reading of the captured tree
  and the R5 frozen tree (LogUp refusal order, stack CLI, verifier-visible
  surface, windows, GS-12, GPU); (3) independent recount of §4's residuals
  from the Rust source. Meanwhile: re-reading the three arguments at the
  trained layout myself.
- 21:18 — own reading so far (candidate findings, to be confirmed):
  (a) the run hash-layer argument's conditions C-R1 (no 40-byte F_U input),
  C-R4 (context a statement constant, never request-derived) and C-R5 are
  not carried by the draft; C-R4 is live: `stack-prove --label` is
  operator-chosen and published as `context_label` (trained_block.rs:1517,
  :1561). (b) the trained statement identity (absorbed as the run's
  calibration word) binds profile.json's SHA-256, and profile.json carries
  `sequences` and held-out `fidelity_T` statistics; the CLI reads the hidden
  input and every per-layer reference activation from `<export>/seq_<id>/`
  (trained_block.rs:875-905), the same directory the verifier needs to
  rebuild the statement: operating hypothesis owed (export frozen before
  and independent of the input; seq_* never shipped). (c) parity refusal
  prints a hidden-derived COUNT and position (trained_block.rs:1688), which
  the draft §6 under-describes; K-2 precedent. (d) statement.json records no
  backend: the CPU-only scope is not auditable from the artifact.
  (e) residual table: B10 (constructor-vs-absorb, 2^-128) and the C(m,2)
  tag-key row missing / conflated; "a million (2^20)" repeats H-7's
  rounding. (f) GS-12's stake at this layout is liveness + one public S-4
  argument, not disclosure. Records read: pass F status PASS carries 1
  unexplained false leaf (CH-6) — classifier says PASS anyway.
- 21:22 — all three helpers reported; load-bearing claims re-checked by me
  in the source:
  * R5 frozen tree `stack-prove` (trained_block.rs:1913-2050 there):
    endpoints sealed from the export's x_in/x_out (R3-1), builder refusals
    and parity now inside the proving pass after the header and after
    segments 0..k-1 (best-effort `remove_dir_all`); in-process verification
    OFF by default (R5-2) and `statement/` written anyway. Contradicts
    ruling H-1's production-caller rule and M-9 / D12b(1) as written, for
    the tree a statement must name. CONFIRMED.
  * gate v4 staged driver: `check_run_layer_pins` returns `suspended` but
    `zk60_native_rg_m125.py:195` only records it; `ok` (:376-380) ignores
    it; status.py:207 says PASS on ok TRUE with unexplained leaves.
    CONFIRMED.
  * `prove_run` = `prove_run_with(SliceBlocks)` in R5 (run.rs:833-835):
    the capture harness and the CLI share the prover core.
  * GS-12 in tree A: enforced through the frozen SiLU registry at the door
    (trained_block.rs:813-816; tables.rs `int16out_generate`, g = 0 -> 0).
  * LogUp: whole exp/act tables inverted AFTER the witness-side
    denominators (protocol.rs:912-967 per helper 2); the "whether" claim
    still holds for builder-admitted witnesses, the D22 §9.10 reason does
    not transcribe.
  * Recount: every §4 figure reproduced exactly (script copied to
    `recount/recount.py`, output `recount/recount.out`, re-run here, exit
    0, under 1 s). B10 row missing, tag-key row mislabelled, L = 1 column
    not in the cited JSON, "a million (2^20)".
  Next: write REVIEW.md.
- 21:28 — `REVIEW.md` written: verdict first; findings P-1..P-22 (2
  blocking: P-1 tree B's stack-prove vs H-1 / M-9, P-2 staged gate driver
  does not enforce pins and PASS ignores unexplained leaves; 11 must-fix
  P-3..P-13; 9 wording P-14..P-22). Helper-cited line numbers spot-checked
  (`--label` at :1639; m125.py :211 / :315; status.py :77; M9-3 exception
  path). No job launched; nothing pending. Lane closed; report to the
  coordinator. NOT a privacy acceptance.

## ROUND 2 (coordinator brief received; opened 2026-10-18 04:40 UTC)

Brief: (1) check P-1..P-22 against the revised draft's §3b; (2) attack the
revised draft and the R5b evidence (verifier-written statement,
`prover_reported` fields, `--seq-dir` split, refusal texts, G-4 criterion as
a false-negative risk); (3) a short closed list of what still separates the
draft from an acceptable statement. Output `REVIEW2.md`, same rules, same
write set. Objects: R5b frozen tree
`results/zk60_1b_native_20261017/r5b/frozen-tree/`, gate tools v6
(`gate-tinyllama.tools.frozen.v6.sha256`), gate evidence
`results/zk60_gate_tinyllama_20261017/r5b/`, D24 review rounds
`R5_VERDICT.md` / `R6_VERDICT.md`.

- 04:40 — round 2 opened; reading the revised draft, the two verdicts, the
  gate ledger's round-5 table, the R5b stack CLI, the v6 tools.
- ~04:50 (10-18) — cut off by the usage limit mid-reading. Read by then:
  the revised draft (all 838 lines, §3b map), R5_VERDICT, R6_VERDICT, the
  gate ledger round 5 + round 6 opening, R5b `stack_prove_inner` /
  `stack_verify_inner` / `promote_statement` / `label_of` / `c_r1` /
  `SeqSource` / `refuse_prover_private_entries` / `load_seq_dir`, the
  r6-vs-r5b patch (protocol.rs, run.rs, shape.rs, trained_statement.rs
  hunks), v6 driver pin enforcement and status classifier, M9-3 code and the
  R5b pass-T M9-3 refusal texts, every R5b status record, stage-47 logs,
  schema / TL-4 / capture logs. Live `scripts/` = frozen v6 (53 of 53).
- 2026-10-19 09:25 — resumed (box rebooted, /tmp wiped; nothing of mine was
  in /tmp). Draft and gate ledger unchanged since 10-18 04:44 UTC; the
  gate's round-6 sub-lanes (G-7, census, v7, P-18 on R6) left no evidence
  dirs. New in the brief: say whether R5b-captured evidence matters for a
  statement naming R6.
- 09:30 — re-checked for R6: `gpu::label()` on a CPU build is a constant
  (`r6 gpu/mod.rs:744-746`); R6 runs CS-3 in the sealing pass
  (`trained_block.rs:2073`); `prover_reported.backend` is any printable
  string ≤ 256 chars, republished by the verifier; R6 `prove_core`'s
  fallible calls = shape checks, CS-3, LogUp inverses, `argument`
  (challenge-only), `check_opening` (challenge-only); pg_rot1 T32's `sh_s`
  is run-wide (6), so R6's per-layer path is inert for it.
  `REVIEW2.md` written: verdict "close, not yet"; P-1..P-22 mapped (17
  closed, 4 partly: P-7, P-12, P-13, and P-1's text; P-18 open); new Q-1..Q-8
  (Q-1 name R6 + re-pin/re-gate, Q-2 `prover_reported` is a C-R4-class free
  field, Q-3 M-9 under N-r6-a, Q-4 P-7 self-report wording, Q-5 text
  consolidation, Q-6 stage-47 at run scope, Q-7 census leaves the privacy
  list with R6's sealing CS-3, Q-8 G-4 criterion); R5b-vs-R6: figures carry
  by reading, the statement must still name R6 (condition 7); closed list of
  5 items. Nothing launched; nothing pending. Round 2 closed. NOT a privacy
  acceptance.

## ROUND 3 (final pass; coordinator brief received 2026-10-19 ~12:00 UTC)

Brief: check round-2 closing items 1-5 on native R7 (R7_VERDICT), re-attack
what the R7 move and tools v7/v8 changed (G-4's tightened criterion, PC-9b,
the CLI-path capture), final verdict in plain words with the exact residual
figures. Objects: draft sha256 080cddbc… (mtime 2026-10-19 11:59 UTC),
`EV/r7/r7-summary.json`, `EV/r7cli/`, `EV/q6/`, `EV/g7/`, tools v8 manifest
sha256 e047fb59… (checked), register D28, D29, D31. Output `REVIEW3.md`.

- 12:00 — round 3 opened; confirmed the draft and v8 manifest hashes the
  brief names.
- 12:03 — read: R7_VERDICT (R7 = R6 + `trained_block.rs` statement-writing
  changes only; Q-2 allow-list holds; N-r6-b closed; N-r7-a..d); the whole
  revised draft (1,019 lines, §3b maps P and Q); register D28, D29, D31;
  Victor's sheet `ZK60_RULINGS_FOR_VICTOR_20261017.md` (D9 figures, 09:31
  UTC; 2^-70.4 ≈ 6.6e-22 per run, ≈ 6.6e-16 per million, checked). Checked:
  live `scripts/` = v8 (54 of 54); `r7-summary.json` (12 records PASS, 0
  unexplained, pins ok, terminal 23/46/506, M9-3 both arms D 48/46 Kv 24/22
  Q 28/26 S 32/30 T 15/13); v8 M9-3 code (exact regex, exact surplus 1/2,
  exact stopped-slot sets); PC-9b construction and its R7 L1 result (NOT-OK
  as designed, 3 stages held, exact); CLI path logs (`prover_start`
  constant backend, sealing before header, fresh `stack-verify`
  `statement-published`, capture = verified bytes = `segments.json`), E3
  identity equal for CLI and harness bundles; stage-47 L = 2 logs on R7 and
  R5b (7 roots, 77,919,360 B, 5 of 5 non-vacuity); R6 `private_block.rs`
  hunk = a test-module line only; R7 queues ran under the v8 manifest.
  G-7's R7 surjection re-run is RUNNING (started 11:58:49 UTC): stage 1 clean
  on all four bundles; stage 2 A 36/36 disclosed 0 on R7 dense-l1 so far.
- 12:05 — `REVIEW3.md` written. Verdict: YES, conditional on G-7's R7
  surjection clause landing as expected (A 36/36 disclosed 0; H 8/9 with the
  sum claim disclosing exactly 2; endpoints / boundary 0), with two wording
  errata (E-1: the draft still lists D28 / D29 / the D9 sheet as owed; E-2:
  the census reading is R5b's, its R7 re-check holds trivially). Round-2
  items 1-5 closed; G-4 two-arm criterion, PC-9b, CLI-path capture and R7's
  writer changes attacked, no new channel. Residual figures unchanged (§4 of
  REVIEW3). The surjection job (gate lane's, not mine) was still running at
  12:04 UTC (no `.done`). Nothing of mine launched or pending. Review lane
  closed. NOT a privacy acceptance.
