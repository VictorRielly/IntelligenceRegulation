# Independent adversarial privacy review, round 6: the frozen-r11 re-pin for D33 and D36

Reviewer: the same independent Claude Opus 5.5 agent as rounds 1–5. I did not
write the note, the tools or the code.
- Written 2026-10-21 02:19–02:22 UTC.
- Paper only, plus short read-only `python3 -I` checks: no builds, proofs,
  git writes or jobs.
- The ledger is `PROGRESS.md`, section ROUND 6.

**This is not a privacy acceptance.** It advises the security owner. Rulings
are Victor's.

**Object:**
`results/zk60_gate_tinyllama_20261017/round15/ZK60_PRIVACY_STATEMENT_REPIN_R11_20261021.md`
(sha256 `a0c28c57…`, checked). The tree is
`results/zk60_token_io_r1_20261017/frozen-r11/` (237 files, `d8075d76…`).

## Verdicts

- **D36 (next-token statement): YES.** The note meets condition 7. Victor
  can extend D36 to frozen-r11, naming the token binary
  **`0c9f247c…`** (checked).
- **D33 (trained-block statement): YES.** The note meets condition 7. Victor
  can extend D33 to frozen-r11, naming the trained-block binary
  **`631e2a15…`** (checked), or a lane-built binary named by digest.

## What I checked

- **The changed set** (`diff -rq` frozen-r9 → frozen-r11):
  - `examples/zk60_token_io.rs` changed, in its doc header only;
  - `token_io.rs` and `token_io/cli.rs` changed; both are pinned;
  - `token_io/cli_tests.rs` changed (tests);
  - `token_io/r11_tests.rs` added.
  - **No block, run, prover, verifier or token-stage file changed.**
- **The two pinned diffs** [read by me]:
  - `token_io.rs`: one `#[cfg(test)] mod r11_tests;` line, plus its comment.
  - `cli.rs`: CLI-only.
    - **TR7-5:** `cli_stage_shape(sh, own)` replaces `seal_chain`'s inline
      derivation with the same expression.
    - **TR7-6:** `owner` refuses an existing `--token-out` before
      re-verifying.
    - **TR7-7:** `tighten_to_0700` on the owners' base. Its stdout event
      names the path and old mode only, so it falls under the
      prover-private-stdout rule.
    - Two `#[cfg(test)]` counters.
  - **Nothing touches the statement the CLI writes, the run directory, the
    transcript, a draw or an opening.**
- **Pins.**
  - Frozen v17 refuses both moved digests by name and suspends: NOT-OK on
    integrity, the new-slot terminals, the block-stage terminals and the
    joint preimage (`ff-v17-tokengate-cli11.json`).
  - frozen_v18 equals its manifest (71 of 71). The gate ran under it; the
    70-file line in the toolcheck is v17's check, used for the probe.
- **D36's measured equality.**
  - The r11 CLI-path capture passes the v18 token gate: PASS, no false parts.
  - Against the r9 CLI capture (`compare_r15.json`): `gate_figures_equal`,
    `nl1_equal` and `surjection_equal` are all true.
  - The run facts differ only in `token_io.input_root`,
    `token_io.output_root` and the `expected_policy_sha256` that contains
    them. All three are per-run randomness; I computed the differing leaves
    myself.
- **D33.**
  - `d33_report_only_check.json` is ok: the block gate enforces 44 files,
    none of them token files, and 49 of 49 other pins equal frozen-r11's.
  - The r11-built trained-block CLI published `statement-published` with
    identity `ef061000…`, at 23,019,088 B, as on tk7 and tk9.
- **§4, the diligence question.**
  - `pg_rot1_b4_T32_cal128/profile.json`: `per_layer_constants_differ =
    [exp_e_s, silu_member]`, and those are its only null
    `profile_constants`.
  - D33's `pg_rot1_export_T32` is the same, as checked in round 1.
  - Both are table keys, checked per stage. The note's conclusion holds.
- **The wording correction** (38 control entries = 36 live + 2 not
  applicable) matches my round-4 reading of the v10 report.

## Items for the two decisions

- **PR6-1 (D36).** Name:
  - frozen-r11's 52 pins (40 R7, 6 r7c, 4 r9, 2 r11);
  - the binary `0c9f247c…`.

  The ten harness captures are carried: no file on their path moved, and
  round 12 measured them on frozen-r9.
- **PR6-2 (D33).** Name:
  - frozen-r11's pins;
  - the binary `631e2a15…`. It was built in a different path from tk9's
    `911e82f0…`, so the decision names these bytes, or a lane-built binary
    named by digest.

  Carried by reading, as in tk9: the block captures (no enforced pin moved),
  P-18's capture, and the 22-block pass F.
- **PR6-3 (optional).** Capture and gate the r11 trained-block CLI run
  directory `~/zk60-artifacts/tinyllama-cli-r11-run-l2/`, as PR4-2 and PR5-2
  suggested.

**No blocking or must-fix items.**
