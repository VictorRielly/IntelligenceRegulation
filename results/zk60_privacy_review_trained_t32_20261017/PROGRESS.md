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

## ROUND 4 (coordinator brief; opened 2026-10-20 00:01 UTC)

Background: Victor accepted the statement as **D33** (2026-10-19 16:56 UTC),
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md` (sha256
ded3f0e7…), in force for native R7 only; R8 changed five pinned files, so
step 3 is suspended for later trees. Two items:
(A) the re-pin note `EV/tk7/ZK60_PRIVACY_STATEMENT_REPIN_TK7_20261019.md`
(sha256 9958e548…, checked) moving D33's pins onto the token lane's
`results/zk60_token_io_r1_20261017/frozen-r7/` (= R8 + token code): does it
meet D33 condition 7 and the D22 4751b93 precedent; judge the carry by
reading of the P-18 capture-and-gate and the 22-block pass F.
(B) the next-token draft `EV/round9/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.md`
(sha256 abccfc64…, checked): attack F-T1 (CS-3 mid-run only), F-T2 (input-
dependent token LogUp refusal counted as distance; compare D30 (4)), the τ /
head-fold caveat, the owed list, the residual recount
(2^-74.43 / 2^-73.62 / 2^-70.35). Output `REVIEW4.md`, findings PR4-n.

- 00:01 — round 4 opened; hashes of the three objects checked.
- 00:05 — launched one read-only helper on the token code (F-T1, sink
  contract, F-T2 inversion sets and counts, token CLI publication surface,
  owners' handoff).
- 00:03-00:09 — (A) checked myself: frozen-r7 vs R7 differ in exactly the
  five files; zkp-core and protocol / argument / layout / boundary /
  endpoint_g / witness / pad / wire byte-identical. Read every code hunk of
  run.rs, shape.rs, trained_statement.rs, trained_block.rs, private_block.rs:
  at an export with no per-layer calibration fields every change is the
  identity (stage_cal = base, own all None, identity encoder writes nothing
  new, ssh = sh); the rest is visibility, token profile strings, a refusal of
  a token profile in a blocks-only statement, `token: None` in the cfg(test)
  capture header. tk7 vs R7 summaries: 10 of 10 records PASS, 0 unexplained,
  every randomness-free figure equal (replay, hash, terminal, channels, mask,
  joint, preimage leaves). v11 frozen copy = manifest (60 of 60); queues ran
  under it. Stage-47 five tests PASS on tk7. tk7 CLI (dac7fc73…): sealed
  before header, statement-published by fresh stack-verify; published
  statement.json vs R7's: 52 leaves each, only `/expected_io` differs
  (checked). (B) residuals recounted: draws, sampler, N_leaf, salt,
  liveness, refusal 2·(768L+T+256)/p² all reproduce; 2T union would give
  2^-116.91; token endpoint H-pad closed form holds at (2^8, 2^11). REVIEW5
  verdict still a placeholder.
- 00:09-00:12 — (B) read myself (times corrected from `date -u` at 00:12;
  the two ranges first written here were guessed): no `check_lookup_misses` call under
  `token_io/` (F-T1 confirmed); stage IN inverts `α − q_t` with q_t =
  τ_tab[tok_t] and the mult ≠ 0 rows only (≤ T distinct, input-dependent);
  stage OUT byte helpers + non-zero histogram rows (≤ 256); constant
  message; unkeyed BLAKE3 on the token path all public and ≥ 96 B (C-R1).
  REVIEW4.md drafted: (A) YES with PR4-1..PR4-3; (B) NOT YET with PR4-4..
  PR4-14; §2.6 (sink contract, CLI surface) waits for the helper's report.
- 00:12-00:15 — read the token CLI myself (`cli.rs:470-560`): NO block
  sealing pass; output token from the export's reference x_out; block
  builder / int16 / parity / CS-3 all post-header; `Claimed::drop` removes
  silently. Helper report in (confirms F-T1 widened, F-T2 and count,
  sink contract; adds silent removal, killed-run leftovers, `--prompt` on
  the command line, owner base beside `captures/`, capture uses
  `stream_pipeline`); spot-checked `cli.rs:268-274, 360-395`,
  `capture_tests.rs:318, 400`, listing of `~/zk60-artifacts/token-io/`.
  REVIEW4.md finished: (A) YES (PR4-1 decision must name 52 pins, the CPU
  binary, the two carries; PR4-2 optional capture of the tk7 CLI run;
  PR4-3 wording). (B) NOT YET, closed list PR4-12: PR4-4 (token CLI breaks
  H-1, R5-pattern; code preferred), PR4-5 (D30-(4)-style ruling for F-T2),
  PR4-7, PR4-8, PR4-9 (narrowed to calibration attribution), PR4-10,
  PR4-15 / PR4-16; should PR4-11; wording PR4-6, -13, -14, -17. Nothing of
  mine launched or pending. NOT a privacy acceptance.

## ROUND 5 (coordinator brief; opened 2026-10-20 05:22 UTC)

(A) re-pin note `EV/tk9/ZK60_PRIVACY_STATEMENT_REPIN_TK9_20261020.md`
(c4d88df1…, checked): D33 frozen-r7 → frozen-r9 (b666a991…); condition 7?
(B) next-token draft v2 `EV/round11/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT_v2.md`
(34562422…, checked) against PR4-12: addendum, D34, D35, token round 9,
REVIEW5/REVIEW6; harness captures on frozen-r7 carried to frozen-r9 by
argument (re-capture running in the gate). Output `REVIEW5.md`, PR5-n,
plainly whether (B) is ready for the security owner and Victor.

- 05:22 — opened; hashes checked; frozen-r9 FROZEN.txt read (236 files,
  12 changed + 3 added vs frozen-r7, one block/run file: run.rs).
- 05:22-05:30 — (A) checked: `diff -rq` r7→r9 (only run.rs on the block
  path; +2 token profile strings, registry 3→5, two shape arms); tk9 vs tk7
  summaries identical on every deterministic figure (10/10 PASS);
  frozen_v15 = manifest (65/65); stage-47 block and token replays PASS;
  tk9 binary 911e82f0 (checked); tk9 CLI statement vs tk7: only
  `/expected_io` differs. (B) read the v2 draft (783 lines), D34, D35, token
  REVIEW5/REVIEW6 verdicts; read the r7→r9 diffs of token run.rs (sealing
  pass moved before the generator/header, nothing after the header changed)
  and stage_in.rs (adds `lookup_misses` only); read CLI `seal_chain`
  (builder chain, int16, parity, CS-3, next token from the builder),
  `--prompt` refusal / `--prompt-file`, `OWNER_BASE`, `leftover_refusal`,
  `REMOVAL-FAILED`; `cheating` is const false outside test builds. Round-10
  evidence: NL-1 records PASS, surjection summaries match, attribution PASS
  (10), CLI capture v14 PASS, token stage-47 bytes equal on r7 and r9 code.
  REVIEW5.md written: (A) YES (PR5-1, PR5-2 optional); (B) READY for the
  security owner and Victor (PR5-3 decision content incl. D29 extension,
  PR5-4 carry suffices, PR5-5..PR5-8 wording / operating). Nothing launched
  or pending. NOT a privacy acceptance.

## ROUND 6 (coordinator brief; opened 2026-10-21 02:19 UTC)

Victor accepted D33 extended to frozen-r9 and the next-token statement v3
as D36 (2026-10-21 ~00:17 UTC). Item: the round-15 re-pin note onto
frozen-r11, `EV/round15/ZK60_PRIVACY_STATEMENT_REPIN_R11_20261021.md`
(a0c28c57…, checked), covering both statements. Question: condition 7 met
for D33 and D36, YES / NO each. Output `REVIEW6.md`.

- 02:19 — opened; hash checked; frozen-r11 vs frozen-r9: 4 changed
  (examples doc header, token_io.rs, cli.rs, cli_tests.rs) + 1 added
  (r11_tests.rs); no block / run file.
- 02:19-02:22 — read both pinned diffs (token_io.rs: one cfg(test) mod
  line; cli.rs: TR7-5 refactor, TR7-6 owner refusal, TR7-7 base
  tightening, cfg(test) counters); frozen_v18 = manifest (71/71); v17 probe
  NOT-OK, v18 token gate PASS; compare_r15: gate figures, NL-1, surjection
  equal, run facts differ only in input/output roots and the policy digest
  (leaves computed myself); d33_report_only_check ok (44 enforced files, no
  token file); binaries 0c9f247c and 631e2a15 checked; r11 trained CLI
  publishes ef061000; b4 per-layer fields only table keys. REVIEW6.md
  written: D36 YES, D33 YES (PR6-1, PR6-2 decision content; PR6-3
  optional). Nothing launched or pending. NOT a privacy acceptance.
