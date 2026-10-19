# Privacy gate, sub-lane P-18 on R7: one capture through the CLI's own path (L = 2)

Review finding P-18 of `../PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md` (§1
"Evidence path", §10b item 5). Every earlier gate bundle was made by the test
harness (`TrainedChain` + `run::prove_run` + `RunStatement::new_bound`). This
sub-lane makes ONE bundle whose RECEIPT BYTES were written by the production
CLI's prover (`zk60_trained_block stack-prove`, the native R7 release binary),
verified first by the CLI itself in a fresh process (`stack-verify`), then
captured by verifying the SAME run directory with the CLI's own verification
function (`run::verify_run_from_dir_hashed_with`), the gate's recorder
attached.

**Nothing here is a privacy acceptance.** A capture is the INPUT to the run
privacy gate; the coordinator gates it; only the security review process can
accept, and rulings are Victor's (`docs/zkmatrix-poc/ZK60_DECISIONS.md`).

Supersedes `../r6/` and `ops/zkp-mvp/trained-1b-gate-r6/` (R6 capture
cancelled 2026-10-19 09:32 before any job ran: the R6 CLI's free
`prover_reported.backend` was review item Q-2). Both are left as they are.

Write set (exclusive): `ops/zkp-mvp/trained-1b-gate-r7-cli/`, this directory,
new `/home/victor/zk60-artifacts/tinyllama-cli-r7-*` directories:
`…-seq-ho00/` (prover-private input), `…-verifier-export/` (the export
without `seq_*`), `…-run-l2/` (the CLI's run directory; its
`.unverified-statement` sibling is removed by `stack-verify` itself),
`…-capture-dense-l2/` (the bundle). `ops/zkp-mvp/trained-1b-gate-r7/` is the
coordinator's copy, read-only here.

Rules: `ops/zkp-mvp/LANE_RULES_20261017.md`. Costs [MEASURED, shared box,
n=1] unless labelled otherwise.

## Ledger (UTC from `date -u`)

- 10:03 resumed on R7 (coordinator message 10:03).
  - R7 CLI `results/zk60_1b_native_20261017/r7/zk60_trained_block.release.bin`
    sha256 `e51cc6a4ef27321b121d6f0455a1817cf8c84e6f4333b5168d9de051292f78d1`
    = `r7/binaries.sha256` [checked].
  - Copy: `rsync -a --exclude='target*'` of `r7/frozen-tree/` into
    `ops/zkp-mvp/trained-1b-gate-r7-cli/`; `verify_copy.py` (this dir, = the
    r6 one) → `verify_copy.before_patch.json`: 219/219 against
    `r7/manifest_frozen.json` (sha256 `eb86d448…9069`), 0 mismatch / missing /
    unlisted, tree `36a8aed1…3520` REPRODUCED (native formula).
  - Read R7 against R6 (`r7/r7-vs-r6.patch`, 331 lines): body-compared the
    pieces the test mirrors — `stack_records`, `stack_context`, `BlockCache`
    (struct + impl), `CacheBlocks` (+ its `BlockSource` impl), `parse_layers`,
    `refuse_prover_private_entries`, `label_of`, `c_r1`: IDENTICAL to R6.
    `stack_verify_inner` differs only by N-r6-b's
    `clear_stale_writing_dirs(&art)?` before the statement lookup (the test
    mirrors it as a refusal of any `statement.writing-*` entry, mutating
    nothing). Q-2 touches the prover / statement parser only.
  - Capture patch `../trained-1b-gate-vs-review-r2.v2.patch` applied: three
    `run_capture.rs` hunks at offset 24, `run_capture_tests.rs` clean.
    Patched `run_capture.rs` sha256 `31557a2722997d900bcf21e67f3aa312b9bf7f70ea81a0212470c32602c5be6f`
    (= R5b / R6 copies, as required).
- 10:06 test `capture_a_cli_run_directory` appended to the copy's
  `run_capture_tests.rs` (test-only, `#[ignore]`; no other file touched). What
  it does, in order (each step names the CLI line it mirrors in the code):
  C-R4 label allow-list; P-5 refusal of any `seq_*` in the verifier export;
  `TrainedExport::load`; `A..B` layers (B exclusive, each in the export);
  `run_constants` / `shape_for` / per-layer `load_layer(..,false)` digests and
  records / `statement_of_records` (= `stack_records`); `stack_context`
  (C-R1 included); N-r6-b as a non-mutating refusal of `statement.writing-*`;
  requires `<run>/statement/` with exactly the three verifier files and no
  `.unverified-statement` sibling; `statement.json` (the CLI's strict parser)
  must name schema `zk60-trained-stack-run/2`, the FRESH-PROCESS writer, the
  rebuilt identity, label, context and `expected_io`; `expected.bin`
  canonical with this context; `RunStatement::new_bound_from_digests`;
  asserts the header's calibration word = the identity; recorder attached;
  **`run::verify_run_from_dir_hashed_with(&rst, &mut CliBlocks, &art)`**
  (`CliBlocks` = test-local mirror of the private `CacheBlocks`); the
  returned hashes must equal `statement/segments.json` entry for entry; the
  segments re-read through `run::read_segment_bounded` must equal them;
  `write_bundle` + `check_bundle_on_disk`.
- 10:07 build queued (guard class build, need 3 / cap 5, detached; label
  `p18-r7cli-build`; `p18-build.{log,done,guard.json,sh.done}`).
- 10:08 inputs: `rsync -a` of `seq_ho00/` → `/home/victor/zk60-artifacts/tinyllama-cli-r7-seq-ho00/`;
  `rsync -a --exclude='/seq_*'` of the export →
  `/home/victor/zk60-artifacts/tinyllama-cli-r7-verifier-export/` (the native
  rule: top-level `seq_*` only; the loader takes the variant from
  `profile.json`, not the directory name). `check_inputs.py` →
  `inputs.json`: seq 45 files = the export's `seq_ho00/`, verifier 312 files =
  the export minus `seq_*`, no `seq_*` entry, ok (lists
  `inputs.seq-ho00.sha256` `f803f6a5…f275`, `inputs.verifier-export.sha256`
  `12c406e7…212f`).
- 10:08 stack-prove queued (guard class cpu, need 3 / cap 4.5, max 1800,
  detached; label `p18-r7cli-stack-prove`; `p18-prove.{log,done,guard.json,sh.done}`):
  `r7/zk60_trained_block.release.bin stack-prove --export <full export>
  --seq-dir /home/victor/zk60-artifacts/tinyllama-cli-r7-seq-ho00 --out
  /home/victor/zk60-artifacts/tinyllama-cli-r7-run-l2 --layers 7..9 --label
  zk60-trained-stack`. Heavy lock then held by `tio-s5-suite` (need 6.5).
- 10:16 stack-prove DONE, exit 0 (`p18-prove.log`, `p18-prove.guard.json`):
  waited 460.5 s for the lock, child wall 5.70 s, peak RSS 1.02 GiB, peak
  cgroup 1.02 GiB [MEASURED, shared box, n=1]. Events: prover start on
  backend `gpu: off (built without --features gpu-cuda)` (= Q-2's
  `BACKEND_CPU_BUILD`); sealed over layers 7..9 with parity bit-exact at both
  layers before the run header; 2 segments, 23,019,088 B
  (`segment-000.bin` 11,320,120 B sha256 `62bc57b0…2827`, `segment-001.bin`
  11,698,968 B sha256 `6c781e2a…e479`); not verified in-process, so the
  prover statement went to `tinyllama-cli-r7-run-l2.unverified-statement/`.
  **Trained statement identity
  `ef0610008901e09101709db727a19b30a5de9afb64217e284432afe892aaeb54`**
  (public). The prover's unverified statement copied to
  `prover-unverified-statement/` before `stack-verify` removes it
  (`statement.json` `e73faf72…19b1`, `expected.bin` `788631b1…4684`,
  `segments.json` `10b80b44…b2c8`).
- 10:16 stack-verify queued (guard class cpu, need 2.5 / cap 4, max 1800,
  detached; label `p18-r7cli-stack-verify`; `p18-verify.*`): fresh process,
  `--export /home/victor/zk60-artifacts/tinyllama-cli-r7-verifier-export
  --artifact /home/victor/zk60-artifacts/tinyllama-cli-r7-run-l2
  --expect-statement ef061000…eb54 --layers 7..9 --label zk60-trained-stack`.
