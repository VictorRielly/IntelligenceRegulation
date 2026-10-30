# Token review, round 14 — reviewer ledger (resumable)

Scope: independent soundness / code review of `results/zk60_token_io_r1_20261017/frozen-r14/` (rung R-C3, short
items; N-r13-1/-2/-3/-6 and low notes). Not a privacy review. Output: `REVIEW_R14.md`. Scratch (mine):
`ops/zkp-mvp/token-io-review-r14-scratch/`. Evidence: `r14/` here. Fixtures/TMPDIR: `~/zk60-artifacts/token-io/review-r14-tmp/`.

## Log (UTC from `date -u`)

- 2026-10-29T02:14Z start. Read CLAUDE.md, LANE_RULES (guard 88af4c63, lean-memory rule), D45 / D41, REVIEW_R13,
  lane PROGRESS round-14 section, frozen-r14.FROZEN.txt. WINDOW_HOLD absent; guard status: budget 0, locks free.
- 02:15Z copied frozen-r14 -> ops/zkp-mvp/token-io-review-r14-scratch (cp -a). Tree check script r14/tree_check_r14.py.
- 02:16Z tree check (r14/tree_check_r14.json): frozen-r14 and my copy = manifest_final_r14 (258 files, list sha256 0b4c429b…,
  0 changed / missing / extra); vs frozen-r13: 14 changed, 1 added, 0 removed (= the lane's list); 10 native files differ
  from R12b, of which only run_capture.rs changed in r14. Per-file diffs saved in r14/diffs/.
- 02:17-02:28Z read the r14 diffs in full (classify.rs, classify_tied.rs, classify_run.rs, classify_cli.rs, stage_in_c.rs,
  stage_out_c.rs, run_capture.rs, examples, tests) and the native causal-mask relation (argument.rs SC_SZC c2 clause,
  SC_RS row sum, SC_PV over all s; causal_mask_at public). Lane evidence tallied: s18 29 binaries 845/0/56 (845 ok lines,
  all 14 new r14 tests ok, 1 ignored); red-tests 0/3/1 (the 3 named reds); red-r13-binary 0/1/0 (refused by name);
  bin-short-r14 1/0/0 with HL_PB_CLI_BIN = the r14 binary (sha256 48dac988… recomputed); Shieldstral r14 digests
  baff04d2… / 1f5cb346… = r13's; mut-{n2,pad,bind} each 0/1/0 (killed).
- 02:29-02:34Z reviewer edits in MY scratch only: token_io.rs (`mod review_r14_tests` + the cfg(test) switch
  `rv14_mut`, env RV14_MUT), mutation sites in classify_tied.rs (n2, bind, src), classify.rs (check-tables, n-free,
  size-from-n, vr-last, empty), stage_in_c.rs (pad), run_capture.rs (replay); review_d24_tests.rs gains two
  pub(super) wrappers of its forge hook (rv14_set_forge / rv14_forged_count). New test file
  token_io/review_r14_tests.rs (S1-S7 + ignored S8). Queue r14/run_rv14.sh (build | baseline | xbin | mut), every
  launch behind WINDOW_HOLD + "no other non-light job live"; TMPDIR / HL_TIO_FIXTURE_DIR =
  ~/zk60-artifacts/token-io/review-r14-tmp.
- 02:34:43Z queue (build) started; waited for another lane's build (activated-build-2); 02:36:03Z build launched
  (need 2.7 / cap 3.5).
- Static findings so far: (a) causality holds IN THE RELATION, not only the witness: SC_SZC's division clause
  c2 = mask*E*2^F_P - P*Sum - rho with the public causal_mask_at(sh), P / rho / sigma byte limbs, forces P = 0 at
  j > t (DD path: the tuple (Sum, mask*E, P) gives floor(0) = 0); SC_RS sums mask*E; SC_PV sums P*V over all s;
  every other block op is row-local. DESIGN §15.2 cites the witness (MASK_SCORE) as the reason: doc gap.
  (b) DESIGN table rows C-4/C-5/C-6/C-8 (lines 33-37) and §5 / §6 headers still say [RULING PENDING] after D45.
  (c) `label` has no expected-total check; README's app recipe does not tell the app to compare content_total
  with the post's length (truncation class, widened from >= 23 ids to any N >= 1 by r14).
  (d) next-token fixtures (cli_tests.rs, r3_tests.rs) still use std::env::temp_dir (TMPDIR set in s18).
- 02:39:05Z build exit 0 (181.6 s, peak 2.21 GiB; test binary hashline-14931f569895103b, sha in logs/test-binary.sha256).
- 02:40:22Z baseline [MEASURED, shared box n=1]: 49 passed, 0 failed, 5 ignored (lane token_io::classify* + my S1-S7),
  60.7 s, peak 0.76 GiB -> later test batches declare 1.5 / 2.5.
- 02:41:36Z detail (my tests, --nocapture): 7 / 0 / 1; xbin (S8 with the lane's r12 / r13 / r14 binaries): PASS, only
  the diagonal verifies; r12 / r13 refuse to prove the 22-id item; neither verifies r14's short receipt; r13 segments
  under r14's statement and r14 segments under r13's refused; r13 receipt relabelled /3 refused.
- 02:41:46-02:54:45Z ten mutants (RV14_MUT), each a full token_io::classify + review_r14 batch: ALL KILLED
  (r14/mutation_table_r14.{py,json}). n2 reproduced: "A DERIVATION THAT READ ANOTHER profile.json WAS ACCEPTED".
- ~02:55Z coordinator fairness request (Sol's release build): my mut chain had just ended; the post script
  (run_rv14_post.sh: build2 + S5b under pv-all + xbin2 + baseline2) started 02:55:03Z and sits in its wait_clear
  behind release-1-build (running since 02:54:46Z), so the request's condition (a "release*" job running) held
  before my next build. No signal sent, nothing edited while running.
- 02:43-02:44Z (source, before build2) witness.rs gains a scratch-only `pv-all` switch (the cheating prover's PV
  over every source position) and review_r14_tests.rs gains S5b (the consistent pad-row forgery); S8 prints the
  refusal line.
- 02:59:05Z build2 launched (after release-1-build left the lock); 03:02:24Z exit 0 (199.6 s, 2.15 GiB).
  03:02:38Z s5b PASS: the consistent pad-row forgery (RV14_MUT=pv-all, P = 64 at masked entries, PV over every
  source) is refused at block 0 slot 17 "06 softmax zero-check" (the division clause) in all 3 cases; one moved
  the margin 5,269,429 -> 5,214,444 (the pad row really reached the verdict row). 03:02:49Z xbin2 PASS (refusal
  reasons recorded); 03:03:51Z baseline2 49 / 0 / 6. Post queue ended 03:03:51Z.
- ~03:04Z coordinator standing request (one guarded job for all remaining mutations; then wait for a
  release-/sol- start or 4 min before any heavy launch): acknowledged. All my mutation and attack runs had
  already finished (03:03:51Z); I launch no further heavy job in this review.
- 03:05Z REVIEW_R14.md written: ACCEPTED on soundness for round 14's scope, no fix before the next step;
  notes N-r14-1..6; C-13 list (§10). Scratch diff r14/review_scratch_vs_frozen_r14.diff (8 files, sha256
  6ae2250d…); frozen-r14 re-checked: 0 changed / missing / extra. Leftover synthetic test output:
  ~/zk60-artifacts/token-io/review-r14-tmp/r14-n2-185525 (the n2 mutant's stub profile.json; no private data).
  Nothing of mine is running.
