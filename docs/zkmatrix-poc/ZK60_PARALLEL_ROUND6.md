# ZK60 round 6 — public multi-block composition and review

Baseline: `a118da4`, branch `perf/zk-batch-optimizations`. Implementation validated.
Claude/Fable review handoff separately committed/pushed as `606a24e`.
Victor requested continuation; existing parallel-agent authorization applies.

## Scope and ownership

- Codex lead: this ledger, task/status handoffs, new
  `hashline/examples/zk60_chain_receipt.rs`, CLI integration tests and validation.
- Codex `benchmark_harness`, isolated clone under `/tmp/zk60-round6-scuFsJ/chain`:
  new `hashline/src/public_chain_receipt.rs`, `hashline/tests/zk60_public_chain.rs`,
  additive `lib.rs` registration, and the narrowly scoped fixed-layer profile
  check in `public_block_receipt.rs`. No other production source edits.
- Codex `pending_api_review`: read-only review of Claude's latest CL2/CL3/CL4
  source and evidence. No edits or GPU runs in Claude's checkout.
- Codex `private_block_plan`: inventory followed by an explicitly authorized
  test-only actual-FFN disclosure diagnostic in isolated clone
  `/tmp/zk60-round6-scuFsJ/privacy`. Own new
  `hashline/src/zk_ffn_mask_diagnostic.rs`, test-only registration/observer in
  `hashline/src/zk.rs`, and `ZK60_FFN_MASK_DIAGNOSTIC.md`. No `pcs.rs` edits,
  protocol repair or independent-audit clearance. Capture only verifier-rebuilt
  public claims/transcript; extract without witness, pads, salts or RNG state,
  and compare against the fixture only outside the extractor after verification.
  **Outcome:** the implementation worker encountered a tool refusal and left
  its checkout clean. No test hook or real-FFN diagnostic was implemented/run.
  The lead retained the completed read-only findings in
  `ZK60_FFN_MASK_INVENTORY.md` and queued independent work in `ZK60_FABLE_QUEUE.md`.
- Claude retains GPU/PCS, memory planner and CL2–CL11 queue ownership.
  Fable retains independent privacy/identity review ownership.

## Acceptance and limits

B5 is a **public**, CPU-only composition of exactly two supported blocks,
with independently approved ordered contracts, shared request context and
authenticated public residual continuity. It is not recursive aggregation,
private composition, token generation, a security audit or a throughput result.
Existing B4 layer-zero bytes and all legacy prover paths must stay unchanged.

The chain verifier must decode bounded bytes without weights or witness/oracle
execution, bind layer order/count and external tensors, reject swapped, missing,
duplicated, spliced and relabelled receipts, and check exact signed residual
words plus approved scale/class compatibility. Acceptance is all-or-nothing.
Tests distinguish true constituent proofs from metadata-only fixtures.

Private A03/A04 source implementation remains gated on the reviewed masking
plan. The completed source inventory supports that gate; the planned actual-FFN
test-only diagnostic was not implemented or executed.
No large laptop GPU runs. Heavy CPU checks use `/tmp/zk-heavy.lock`, two threads
and persistent logs; runs expected over five minutes detach with exit markers.
Uncontrolled timings are diagnostics only.

## Closure

- **143 integrated Rust tests pass** (12 B5 entries including the isolated
  process helper, plus two new CLI unit tests); all targets CPU release/offline.
- **144 full Python/native tests pass, zero skips**, 943.832 s. Both formerly
  skipped real-data P0/P2 composition smokes execute successfully again.
  Maximum reported RSS 1,707,152 KiB; zero swaps. Per-process address-space
  cap 8 GiB, two build/Rayon/native threads and shared heavy lock.
- Four frozen 12-layer CPU artifacts retain their exact lengths and **full
  SHA-256**. Original B4 layer-zero receipt retains 2,144,946 bytes and
  `ba5d82150b92e1ef4f58a29fe90fc65c756ac2f49c18f6df6b5de3f6f2fc6b94`.
- Complete 4,290,981-byte B5 receipt verifies in a separate process using only
  2,160-byte independent expected state and four approved roots. Wrong-root,
  overwrite and GPU-environment CLI cases refuse. The synthetic receipt and
  expected state are persisted under `results/zk60_round6_*` for reproduction.
- Independent read-only B5 source/CLI and final-test review found no introduced
  blocker. Tests include **two individually valid** constituents with unequal
  actual residuals, and fresh proofs reaching both arithmetic endpoint refusals.
- No GPU run, source merge from Claude, private-protocol change or new executed
  FFN disclosure diagnostic. Fable's independent privacy/identity gate is open.

Exact commands, source/binary/artifact hashes and resource evidence:
[`results/zk60_round6_validation.json`](../../results/zk60_round6_validation.json).
Detached logs/exit marker: `/tmp/zk60-round6-scuFsJ/validation2/validation.done`
contains **0**. The initial attempt's Rust tests/build passed, then its temporary
runner failed because Python 3.10 lacks `hashlib.file_digest`. Logs/marker are
preserved in `validation/`; incremental SHA-256 fixed the runner, and the entire
gate sequence passed in fresh `validation2/`. No repository source fix was
needed for that runner failure. Existing compiler warnings remain unchanged.

## Next work

1. Fable FA1–FA3: actual group evidence, joint privacy assessment and a concrete
   reviewed mask plan. Codex then implements the private pending lifecycle and
   real attention/FFN seams; B5 is not a substitute for those relations.
2. Claude CL3/CL4: finish the pinned integration-review follow-ups, then CL5's
   measured bottleneck profile; preserve the remaining substantial CL6–CL11 queue.
3. Complete-generation coverage still needs embedding, remaining supported
   blocks, final norm/head, token selection and KV/position/window state. Keep
   release/proof-lag policy explicit. The 5090 campaign follows safe memory,
   parity and coverage/security gates; no 60-tokens/s claim is made here.
