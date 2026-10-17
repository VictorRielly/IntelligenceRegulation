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
