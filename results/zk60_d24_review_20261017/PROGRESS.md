# D24 independent adversarial review (trained-1b-review-r1) — progress

Reviewer: Claude (Opus 5.5 subagent), independent of the author lane.
Frozen source: ops/zkp-mvp/trained-1b-review-r1/ (sha256 list trained-1b-review-r1.sha256).
Scratch (mutations only): ops/zkp-mvp/trained-1b-review-r1-scratch/.
No git. Heavy jobs through scripts/zk60_resource_guard.py.

## Log

- 08:10 UTC: opened. Read CLAUDE.md, ZK60_RESOURCE_PROTOCOL.md, author's
  PROGRESS.md + NOWRAP_DERIVATION.md, D16 / D24 / register table, contract
  review HANDOFF.md.
- 08:20 UTC: verified frozen copy against trained-1b-review-r1.sha256 (191
  entries, all OK; identical to ops/zkp-mvp/trained-1b/). Read the whole patch
  for shape.rs, layout.rs, argument.rs (SC_TZC, SC_DZC, SC_SZC), witness.rs,
  kernel-shaped lib.rs, run.rs, trained_statement.rs, trained_block.rs,
  protocol.rs transcript, hash_domain imposed rule, s24/s25/s33/s35 diffs.
  slot_ir.rs, parity.rs, refusals.rs, tamper.rs, norm_alias.rs, run_capture.rs
  are cfg(test) (checked in private_block.rs).
- 08:35 UTC: candidate finding F-1 (f_e is an unvalidated export constant at
  the trained TinyLlama profile; the softmax quotient relation can wrap the
  field for f_e >= ~49 at T = 32). Scratch copy created (rsync of frozen copy,
  author's target/ copied for dependency reuse).
- 08:45 UTC: reviewer_nowrap.py (own checker, written from the Rust, not from
  nowrap_check.py) run under the guard (light, exit 0): norm clauses over the
  class corners max 2^48.039 (C0), R4 2^48.0, C1 2^41, host WO 2^26.2 -> about
  16 bits under p; uniqueness of D and y on 60 hard rows (incl. all -32768,
  ceps 2^40, cn 2^20, widths 384/2048/4096); max tn 10 @2048, 9 @4096, 11 @384
  (10 at ceps 2^40); alias (p-1)/2 outside the 3-limb pin. Agrees with the
  author on the norm. SOFTMAX (not in the author's derivation): the quotient
  clause bound reaches p at f_e = 49 (T = 32); an all-equal-row forgery exists
  at f_e = 50 (p 16 -> 527, c2 = -P). reviewer_nowrap.json.
- 08:50 UTC: scratch edits (scratch only): witness.rs cfg(test) forge hook in
  the softmax loop; private_block.rs registers review_d24_tests; trained_block_
  tests.rs write_export/Fault made pub(super). New module
  review_d24_tests.rs (tests A-D fast, E-F heavy/ignored).
- 08:52 UTC: launched guarded build+fast tests (r-fast, class build,
  detached); queued behind the calibration lane's light jobs (budget 11.5 of
  11.89 GiB committed) and another lane's r2-compile.
- 08:43 UTC (from `date -u`): CORRECTION — the four entries above stamped
  08:20-08:52 were written without reading the clock; the real times were
  about 08:13-08:30 (the guard stamped r-nowrap END at 08:23:20 UTC). Added
  fast tests G (class corner end to end at the rung) and H (Layout does not
  re-validate an edited trained shape) to the scratch module before the build
  started. r-fast still queued: the heavy+build locks are held by another
  lane's guarded `r2-compile`, which itself waits for budget (the calibration
  lane's light jobs keep 11.5 of 11.89 GiB committed).
- 08:56 UTC: r-fast done (exit 0; release build 2 m 47 s, 6 passed, 2
  ignored; r-fast.log). Results: A — the trained TinyLlama door admits EVERY
  f_e in 4..=62 (63/64 panic in exp_member; the shaped reference kernel
  refuses f_e >= 32), and a trained-model statement naming the pinned
  TinyLlama checkpoint constructs at f_e 50. B — an unbound run at the
  trained rung profile constructs and absorbs calibration_identity(). C —
  new_bound constructs at the FROZEN rung-G profile with a statement naming
  the TinyLlama checkpoint. D — identical export bytes under two directory
  names give two statement identities. G — the class corner (tn 10, Cn 2^20
  both, Ceps 2^40, sh_ao 8) proves and verifies at the rung; verifiers one
  unit off each constant refuse; witnesses honest under each neighbour are
  rejected (slots 14/14/2/14/14). H — Layout::for_shape accepts a trained
  shape edited after the door to cn_a 2^40, ceps 2^50.
  Test binary saved: review-test-binary.bin (+ .sha256).
- 08:56 UTC: launched heavy E+F (class cpu, need 2 / cap 4 GiB, detached).
- 08:57 UTC: heavy E+F done (exit 0, 51 s, r-heavy-ef.log). E: at the trained
  TinyLlama profile with f_e 50 (synthetic words, Wk = 0, the pinned
  TinyLlama model strings in profile.json), one softmax quotient forged
  p 16 -> 527 with sr' = sr - 511 Sum + P (c2 = -P over the integers); the
  production CLI bridge (trained_prove_command) proved it (segment
  12,016,648 B) and trained_verify_command ACCEPTED it; the claimed block
  output differs from the honest one in 2,010 of 65,536 words. F (control):
  the naive p + 1 forgery at the same position is rejected at slot 17.
- 08:58 UTC: FRESH-PROCESS verify with the AUTHOR'S saved release CLI
  (t5/zk60_trained_block.release.bin, sha256 1cf9317c..., built from exactly
  the frozen sources per manifest_final_sources.json, 192/192 files equal):
  exit 0, "verified", and all 12 of its own controls refuse
  (r-fresh-verify-fe50.log).
- 09:00 UTC: the same saved CLI's PROVER on the same export (honest witness,
  no hook) refuses: "parity: the native block output differs from the
  exported x_out in 2010 of 65536 words (first at token 31, channel 0)"
  (r-honest-parity-fe50.log). Evidence copied to forgery-fe50/ (statement,
  expected policy, segment, profile, manifest, SHA256SUMS, output-diff.txt:
  token 31 only, max |diff| 101).
- 09:01 UTC: r-controls (class cpu, the review test binary, the AUTHOR'S
  tests only): 82 passed, 0 failed, 5 ignored (heavy) in 23 s — toy schedule
  digest and parameter line pins, the archived pre-lane toy receipt verifies,
  R-5 run header byte identity, slot-IR export digests at every registered
  shape, parity vs the frozen kernel, s24/s25/s33 registry + hash-length
  census, every non-ignored trained_calib / trained_block / norm_alias test
  (incl. the end-to-end half-p alias at the trained rung). Removed only the
  four /tmp/zk60-native-tiny-190072-* dirs this run created.
- 09:02 UTC: review closed. Findings are in the hand-back (not a file, by
  the delegation rule): F-1 BLOCKING (f_e unvalidated at the trained
  TinyLlama profile; forgery verified by the author's saved release CLI in a
  fresh process), F-2..F-6 MINOR, N-1..N-4 notes. Verdict: accept D24's norm
  rule; do not accept the trained profile/loader until F-1 is fixed. No job
  of mine is running. Scratch artefacts: ops/zkp-mvp/trained-1b-review-r1-
  scratch/ (target/, review_out/ export + artifact).

## ROUND 2 (re-review of ops/zkp-mvp/trained-1b-review-r2/)

- 09:46 UTC: opened. r2 sha256 list: 193 entries, all OK. diff r1 -> r2
  (excluding target/): 26 files, including files OUTSIDE private_block
  (gpu/mod.rs, layer.rs, pcs.rs, wcache.rs, zk.rs) and two new modules
  (review_d24_tests.rs, trained_stack_tests.rs).
- 09:50 UTC: read the author's round-2 account (PROGRESS 254-414) and the
  r1->r2 diff (r1-vs-r2.patch, 3,635 lines). Files outside private_block
  (gpu/mod.rs, layer.rs, pcs.rs, wcache.rs, zk.rs) change only the GPU
  decline LOGGING (R2-5 `gpu::declined`, panics only with
  HL_GPU_REQUIRED=1); no proof byte. r2 CLI manifest (157 files) equals the
  frozen r2 copy except s35_tests.rs (test-only).
- 09:51 UTC: reviewer_nowrap_r2.py (light, exit 0, r2-nowrap.log): every
  one-limb (sh 0..8) and two-limb (sh 9..16) remainder window EXACT; honest
  remainders fit for every acc; host relations over the windows <= 2^36.0
  (down at sh_z with f_pad 16384), unique (out, rem); softmax over f_e 9..16
  and every T with wrho_s <= 24: <= 2^33.998; explicit all-equal-row forgery
  search at T32 f_e 16 (every row length, delta, k = +-1, +-2): none; the
  pg_rot1 norm constants admitted (D_max 1,482,910, window 32), C0 2^42.0.
- 09:55 UTC: scratch r2 copy created; new module review_r2_tests.rs (r2_1,
  r2_2 fast; r2_3, r2_4 heavy); forge hook helpers made pub(super) (scratch).
- 10:01 UTC (CORRECTION: the entry above stamped 09:55 was really ~09:53):
  r2-fast done (build+run, exit 0; r2-fast.log). r2_1: a shape built with
  Shape::new under the TRAINED rung profile string but WITHOUT the door
  (flag false, frozen calibration, f_e 50) passes Layout::for_shape and
  single_block_profile_allowed, and the round-1 wrapping softmax forgery is
  ACCEPTED by verify_bytes_at at that shape (127 of 12,288 output words
  false). Not reachable from production constructors (all trained shapes go
  through the door; the door-built rung-TC refuses single-block), and its
  schedule prints the frozen calibration line, so it cannot be confused with
  a door-built receipt — but it contradicts the round-2 claim that a shape
  "built some other way cannot reach a transcript". r2_2: shift windows at
  their edges (tops; bottoms with a tiny recipe; mixed) prove and verify as
  bound runs at the rung; every moved-shift verifier refuses and every
  witness honest under a moved shift is rejected (slots 14/15/17/18); the
  door refuses sh_qkv 0/9, sh_o 8/17, sh_h 17, sh_z 9, sh_ao 9 by name.
- 10:11 UTC: the r2 production CLI (sha256 17d6ab10...) on my round-1 f_e 50
  export: verify exit 1 and prove exit 1, both "f_e 50 is outside its
  declared class 9..=16" at profile.json, no artifact written
  (r2-fe50-verify.log, r2-fe50-prove.log).
- 10:12 UTC: heavy r2_3/r2_4 and the author-test control run queued behind
  the author's GPU stack job (r2-stack-gpu-ho00 holds the heavy lock).
- 10:13 UTC: heavy r2_3/r2_4 done (exit 0, r2-heavy.log): at the trained
  TinyLlama profile with f_e 16 (class edge, sigma_s 3 limbs, Wk = 0 so the
  largest row Sum 32 * 2^16) the honest bound run proves and verifies
  (11,705,160 B); the round-1 wrapping forgery is NOT APPLICABLE (no
  remainder in [0, Sum) for delta 511/1023/-16/1/1, k = +-1); the naive
  p + 1 forgery is rejected at slot 17. r2_4 wrote a TinyLlama export at
  f_e 16 with EVERY shift at the top of its window (qkv 8, s 8, o 16, g 8,
  h 16, z 8, ao 8), pinned model strings, honest x_out.
- 10:17 UTC: r2 production CLI on that edge export (r2_cli_edge.sh, each
  leaf guarded): prove parity bit-exact, segment 11,705,160 B, its 3
  inconsistent-witness controls refused; fresh-process verify exit 0 and all
  19 of its controls refused (incl. each shift and f_e moved by one).
  r2-controls (author's tests with my r2 binary, incl. review_d24_tests,
  trained_calib/block/stack, norm_alias, s24/s25/s33, slot-IR pins, toy
  pins, R-5): 91 passed, 0 failed, 6 ignored.
- 10:18 UTC: round 2 closed; findings in the hand-back. Nothing of mine is
  running. Scratch artefacts: ops/zkp-mvp/trained-1b-review-r2-scratch/.

## ROUND 3 (re-review of ops/zkp-mvp/trained-1b-review-r3/)

- 13:33 UTC: opened. r3 sha256 list: 195 entries, all OK. Guard status:
  heavy/build free, one calibration light job (4.5 GiB). Read the author's
  PROGRESS Round 3 and Round 4 sections.
- 13:45 UTC: read r2->r3 diff (r2-vs-r3.patch, 4,103 lines; changes only in
  private_block: shape, layout, protocol, run, trained_block,
  trained_statement, witness + tests). Scratch r3 copy created; new
  review_r3_tests.rs (r3_1 R2-a, r3_2 endpoint lies, r3_3 CS-6 at the library
  level) and a scratch-only child module in trained_block.rs (r3_4 TOCTOU
  between the digest pass and the reload); write_stack_export made
  pub(super) (scratch).
- 13:41 UTC (CORRECTION: the entry above stamped 13:45 was really ~13:37):
  r3-fast done (exit 0, r3-fast.log, 4 passed). r3_1: R2-a CLOSED (the
  non-door trained-string shape at f_e 50 and at f_e 12 is refused by
  Layout::for_shape and by single_block_profile_allowed; a frozen rung-C6
  edited to f_e 50 is refused by the universal softmax-window check). r3_2:
  in a two-block bound run at the rung, an input endpoint sealed one word off
  is rejected at slot 21, an output endpoint one word off at slot 22, and a
  DIFFERENT chain proved under the honest chain's sealed endpoints at slot 21
  (a different honest chain with its own endpoints verifies: the prover
  seals, D18). r3_3: CS-6 at the LIBRARY level — a statement over blocks A,
  prover and verifier both handed blocks B (one gain word of block 1 moved):
  run::verify_run ACCEPTS; the same proof against the statement's blocks A is
  rejected. r3_4: TOCTOU between the stack's digest pass and the per-block
  reload — refused in all three cases (manifest digest vs profile.json;
  with no manifest digests in profile.json, the BlockCache's block-digest
  check; array SHA vs manifest).
- 13:38 UTC: reviewer_nowrap_r3.py (light, exit 0): at TinyLlama T32/T64/
  T128 and Llama-3-8B T32 every geometry-dependent clause at the class
  extremes is at most 2^48.039 (norm C0); score sums of 128 products 2^21;
  down over f_pad 16384 2^36; softmax c2 at f_e 16 <= 2^33; LogUp
  multiplicities tiny. 8B: D_max 2,097,152 (ceps 78617) -> window 32, max tn
  9 for every ceps in the class, 2 D_max < 2^24.
- 13:42 UTC: queued r3_queue.sh (serial, each leaf guarded): the author's
  tests with my r3 binary, then a fresh-process stack-verify of the author's
  32-block Llama-3-8B artifact with the r4 CLI (sha256 ca736d48...; its 159
  manifest sources equal the r3 frozen copy except s25_tests.rs).
- 13:56 UTC: r3_queue.sh done. r3-controls (the author's tests with my r3
  binary): 99 passed, 0 failed, 10 ignored — incl. review_d24_tests (A-H,
  r2_1, r2_b, the T -> profile mapping, G corner), r4_tests (8B counted
  layouts, tn 9 at width 4096, RoPE + checkpoint pinned per profile, the 8B
  table digests), trained_stack_tests (3-layer stack, 11 controls, boundary
  lie), witness_speed (parallel == sequential at the rung), s24/s25/s33
  registry + hash-length census with the T64/T128/8B strings, slot-IR pins,
  toy pins, archived toy receipt, R-5. r3-8b-fresh-verify: the r4 CLI
  stack-verify of the author's 32-block Llama-3-8B artifact in a fresh
  process: "verified", 465,815,776 B, statement 259dad7c..., load 81.7 s,
  verify 95.3 s (81.5 s of it block reloads), VmHWM 989 MiB.
- 14:00 UTC: r3-art (build + ignored test r3_5, exit 0): a 2-layer rung
  stack export + proved run directory under the r3 scratch review_out/stack2
  (identity 72098637...), for the resource check with the production CLI.
- 14:10 UTC: the production-CLI stack-verify (honest, --controls) and the
  /dev/zero-segment check are queued for admission (budget full: the
  calibration lane's 4.5 GiB light job + another lane's 7 GiB cpu job).
- 14:12 UTC (entry RECONSTRUCTED at 18:30 UTC by the r3 successor from the
  guard JSONs, the logs and the scratch tree; the original append was blocked
  by a missed permission prompt; the box shut down cleanly 14:59:58 and
  rebooted 18:21). Both runs used the r4 production CLI
  (results/zk60_1b_native_20261017/r4/zk60_trained_block.release.bin, sha256
  ca736d48..., re-hashed 18:30), class light, need 0.5 / cap 1.5 GiB. The
  guard records only cmd[:8], so `--controls` (9th arg) does not show in the
  JSON; the log proves it ran.
  * r3-stack2-verify (ts_end 14:11:57Z, waited 701.8 s for admission, exit 0,
    child 1.27 s, peak RSS 0.04 GiB): `stack-verify` of the 2-layer rung
    stack (export review_out/stack2/rev-stack2, artifact .../stack2/run)
    "verified", 2 blocks, 15,012,880 B, statement 72098637f55f5b49...,
    verify 0.373 s, VmHWM 30 MiB; all 11 run-level controls refused (blocks
    0/1 swapped in the statement -> "segment belongs to another run"; honest
    statement with the verifier's list swapped -> "block 0's public digest is
    not the statement's layer 0 digest"; norm_cn_a+1, sh_z+-1, sh_qkv+-1,
    other export profile digest -> binding mismatch; f_e+1 -> "rung-TC
    geometry fixes f_e = 12"; one block shorter -> counted-length mismatch;
    byte flip -> Merkle path fails; segments swapped / last truncated ->
    counted-length mismatch); honest still verifies. r3-stack2-verify.log.
  * r3-stack2-dos (ts_end 14:11:58Z, exit 137 = child killed by the kernel
    memory cap, guard_killed null, child 0.77 s, sampled peak RSS 1.18 GiB,
    EMPTY log: no "rejected" line was ever printed). Artifact
    .../stack2/run-dos = the honest run with segment-000.bin replaced by a
    SYMLINK to /dev/zero; segment-001.bin and statement/ byte-identical to
    the honest run (cmp, 18:30); statement/segments.json still says segment 0
    is 7,398,936 B. Interpretation: see the 18:3x entries below.

## ROUND 3 continued (successor session, after the 18:21 UTC reboot)

- 18:30 UTC: resumed from this ledger. Frozen r3 copy re-verified against
  trained-1b-review-r3.sha256 (195 entries, all OK; the unlisted files are
  target-gpu/, results/ fixtures and gpu/kernels.cu, as in r1/r2). r4 CLI
  re-hashed ca736d48... = binaries.sha256. Guard status: heavy held by
  another lane's gpu job (t2-debug-small), budget 3.0 / 11.89.
- 18:31 UTC: CODE READ (frozen r3): `stack-verify` ->
  trained_block.rs:1976 stack_verify_inner -> :1998
  run::verify_run_from_dir_with -> run.rs:1057-1070, which does
  `std::fs::read(p)` on each segment path with NO bound: no
  symlink/file-type check, no comparison of the file length with the
  verifier's own counted length (wire::segment_len, computable before the
  read from st.stage_layout(k) and st.seg_geom(k)), no ceiling. The length
  is compared only after the whole file is resident, in
  wire.rs:438-442 decode_segment. run_sink.rs:90 segment_paths checks
  entry NAMES only (a symlink, device or FIFO named segment-000.bin
  passes). statement/segments.json is never read by the verifier. The
  single-block `verify` command does NOT have the hole: trained_block.rs:1355
  uses read_bounded (:294: symlink refused, regular file only, len <=
  wire_ceiling 256 MiB before the read). --controls additionally reads all
  L segments resident with an unbounded fs::read (trained_block.rs:2021).
- 18:31 UTC: bounded reproductions with the r4 CLI (each guarded, light):
  r3-stack2-sparse: segment-000.bin = a SPARSE regular file of 512 MiB
  (truncate; no disk used): exit 1 "segment 0 is 536870912 B, the counted
  length is 7398936" -> the whole file was read before the comparison.
  r3-stack2-sparse-time: the same under /usr/bin/time -v: Maximum resident
  set size 527,448 KiB (515 MiB) [MEASURED] for a 15 MB honest receipt.
  r3-stack2-fifo: segment-000.bin = a FIFO: the verifier blocks in open()
  forever; killed by the guard's --max-secs 20 (exit 75, child 143, empty
  log). Together with 14:11 r3-stack2-dos (symlink -> /dev/zero, killed by
  the 1.5 GiB kernel cap, exit 137): finding r3_6, VERIFIER DoS (memory
  exhaustion / hang), NOT soundness (nothing false is ever accepted; every
  case either refuses or dies). Scratch dirs run-sparse/ and run-fifo/
  (a named pipe) left under review_out/stack2/. No reviewer job live after
  18:32 (guard status).
- 18:34 UTC: Round-4 items re-read in the frozen copy for the verdict:
  derive_at_width (shape.rs:216; D_max 2,097,152..2,344,687 over the ceps
  class, 22 bits -> tn <= 9, 2 D_max < 2^24 [COUNTED]); the door + the
  check_trained_class re-check; trained_rope_theta per profile (500000 8B)
  enforced in check_honoured_by_code and encoded in the statement;
  pinned_for_profile (TinyLlama x3, Llama-3-8B shard-list digest) enforced
  by check_self, waiver test-build only; statement encode binds profile,
  run profile, geometry incl. kv-heads, source pin, calibration incl. RoPE
  base, per-layer block/word/table digests; check_against binds the run's
  block digests. Note N-r3-a: with --rope-from-export the bound tables may
  differ from the pinned base while the statement's rope-theta field still
  names the base (tables are bound by digest; labelling only, not new).
- 18:35 UTC: r3_3 vs the native lane's R5 CS-6 port (READ ONLY,
  ops/zkp-mvp/trained-1b/, run.rs sha256 8f6f0d04..., trained_block.rs
  c3c60f6b... at read time): RunVerifier::start (run.rs:1004) calls
  blocks.are_the_statements(st) before the header is absorbed, never
  consulting the cheating switch; every verifier entry goes through start;
  SliceBlocks -> blocks_are_the_statements (run.rs:806: count, then
  blocks[k].digest() == st.block_digests[k]); BlockPublic::digest is
  recomputed from every field the verifier reads; BlockCache's enforced list
  is compared with st.block_digests() (trained_block.rs:1657). As written
  it CLOSES r3_3. Its test (cs_port_tests cs6_...) has not run: r5-suite-a
  exit 70 at the shutdown. The R5 tree still has the unbounded segment reads
  (run.rs:1255, trained_block.rs:2119): r3_6 open there too.
- 18:36 UTC: R3_VERDICT.md written. VERDICT: Round-4 Llama-3-8B profile
  changes ACCEPTED on soundness (tn 9 at 4096, derived D_max, per-profile
  RoPE base and checkpoint pin, 8B table digests, statement binding).
  Findings: r3_1 CLOSED (R2-a), r3_2 HOLDS (endpoint binding), r3_3 OPEN in
  r3 (library-level CS-6, not CLI-reachable) -> closed by R5 port as written,
  r3_4 HOLDS (TOCTOU), r3_5 PASS (CLI stack verify + 11 controls), r3_6 OPEN
  verifier DoS (unbounded segment read; minimal fix in R3_VERDICT.md),
  N-r3-a note. Round 3 closed; no new round started; nothing of mine is
  running.

## ROUND 4 (re-review of the native Round-5 tree, ops/zkp-mvp/trained-1b-review-r4/)

- 19:49 UTC: opened. Read LANE_RULES_20261017.md, this ledger, R3_VERDICT.md,
  the native lane's Round 5 notes (PROGRESS 893-1060) and r5/FROZEN.txt.
- 19:52 UTC: copied r5/frozen-tree/ (217 files, no target dirs) to
  ops/zkp-mvp/trained-1b-review-r4/; sha256 list
  ops/zkp-mvp/trained-1b-review-r4.sha256 (217 entries) equals
  r5/manifest_frozen.json file for file (0 missing, 0 extra, 0 mismatch);
  the tree hash over sorted "path hash" lines recomputes to d67fae7e...
  = FROZEN.txt. Scratch: ops/zkp-mvp/trained-1b-review-r4-scratch/.
- 19:53 UTC: r3 -> r4 diff (r3-vs-r4.patch, 2,695 lines, 23 files = the
  author's round5-vs-review-r3.patch size); only private_block/ changes.
  Read every non-test hunk: run.rs (CS-6 count + digests in prove_run_with /
  RunVerifier::start, CS-7 registry, CS-8 private fields,
  read_segment_bounded), protocol.rs (CS-3 refuse_lookup_misses before the
  A mask draw, CS-1/4/8 at every entry and in prove_core/verify_core),
  shape.rs (CS-9 registry, check_constructed), layout.rs
  (check_is_for_shape), private_block.rs (check_words split, IoSpec CS-4,
  off-support parallel pre-scan), trained_block.rs (reload_block without
  SHA, parallel digest pass and array loads, parallel pad_matrix, BlockCache
  count/fit_the_shape/are_the_statements, in-process verify off, stack
  controls through the bounded reader), trained_statement.rs (parallel
  word hashes, LayerRecord::unhashed), timing.rs (byte counters).
  Code-read verdicts so far: CheatingProver and cheating_prover_is_on are
  #[cfg(test)] only and the run prover's switch is `false` under
  cfg(not(test)); the verifier never reads it. Only two BlockSource impls
  (SliceBlocks, CacheBlocks). Shape derives PartialEq over every field;
  IoSpec CS-4 compares every shape-derived field. All non-registered
  Shape::new callers are test-only. timing.rs imports no transcript.
  The off-support pre-scan scans exactly the entries the sequential loop can
  refuse on and falls back to that loop. get() order = names order in the
  parallel array load. The verifier's digest pass is the FULL load (array
  SHA vs manifest, manifest SHA vs profile.json) before the statement pin;
  only the reload skips the SHA and it is digest-checked.
- 20:02 UTC: scratch copy ops/zkp-mvp/trained-1b-review-r4-scratch/ (r4 copy
  + target/release from the r3 scratch). Review modules (scratch only):
  review_r4_tests.rs (r4_1 r3_3 retest both sides, r4_2 off-support
  pre-scan vs the round-3 loop, r4_3 CS-8 field-write sweep, r4_5 bounded
  segment reader under a concurrent swap) and review_r4_inner in
  trained_block.rs (r4_4a SHA-free reload TOCTOU, r4_4b parallel digest
  pass == sequential + first error in layer order, r4_4c streaming CS-6,
  r4_4d parallel pad == sequential, r4_4e export reader under a concurrent
  swap); write_stack_export made pub(super). Fixtures
  (r4/make_fixtures.py): the round-3 2-layer rung stack (statement
  72098637...) with segment 0 a /dev/zero symlink, 512 MiB sparse, FIFO,
  1 B short, 1 B long, a directory, /dev/null symlink, a symlink to the
  honest file, segment 1 a FIFO, a hard link (control); exports with
  layer_01/wq.bin a /dev/zero symlink / FIFO, layer_00/wq.bin 300 MiB
  sparse, and exp-fat (all 22 arrays 255 MiB sparse, under the 256 MiB
  per-array bound).
- 20:04 UTC: launched r4/r4_queue.sh (detached, serial, each leaf guarded):
  CLI from the PRISTINE frozen copy (--target-dir in scratch), the CLI
  checks, the scratch test build, review tests, the author's full suite
  (--skip review_r4). Queued behind another lane's gpu job (heavy lock).
- 20:14 UTC: r4-cli-build exit 0 (from the PRISTINE frozen copy into
  scratch target-cli; waited ~10 min for the heavy lock). Review CLI
  r4/zk60_trained_block.review-r4.release.bin sha256 bc627953...
  (r4/binaries.sha256). CLI checks, each guarded light 0.5/1.5 GiB:
  * r4-stack2-verify: the R5 CLI's PARALLEL digest pass rebuilds the
    round-3 statement 72098637... (identity pin passes), the round-3
    receipt (15,012,880 B) verifies, all 11 run-level controls refused; the
    three calibration controls now by the run binding ("this segment
    belongs to another run"), f_e by "rung-TC geometry fixes f_e = 12".
    RSS 41 MiB.
  * r3_6 reproductions, segment 0 = /dev/zero symlink, 512 MiB sparse, FIFO,
    1 B short, 1 B long, a directory, a /dev/null symlink, a symlink to the
    honest file; segment 1 = FIFO (with and without --controls): every one
    exit 1 refused BY NAME ("not a regular file ... refused before it is
    opened" / "is N B, the counted length is M; refused before it is read"),
    ~0.05 s, max RSS 10-12 MiB (29 MiB for segment-1 FIFO after stage 0 was
    verified). Round 3: killed at the 1.5 GiB cap / 515 MiB RSS / hang.
    A hard link to the honest file verifies (control).
  * export side: layer_01/wq.bin a /dev/zero symlink -> "a symbolic link",
    a FIFO -> "not a regular file", layer_00/wq.bin 300 MiB sparse ->
    "exceeds the bound 268435456"; each ~0.05 s, ~8 MiB RSS.
  exp-fat (r4 CLI and the round-4 CLI) waiting for admission (1.5 GiB).
- 20:15 UTC: r4/r4_prove_checks.sh (light, each guarded): the review CLI
  proves the 2-layer rung stack WITH HL_PB_TIMING=1 (112 PB-TIMING lines)
  and WITHOUT; both: statement 72098637..., parity bit-exact, receipt
  15,012,880 B, segment lengths 7,398,936 / 7,613,944 = the round-3
  receipt's, "in_process_verified":false. Fresh-process verify of the
  timing receipt WITHOUT the variable: verified + 11 controls refused; of
  the plain receipt WITH HL_PB_TIMING=1: verified. (A generic honest
  witness: the dense trained recipe, per-layer words and tables differ.)
- 20:26 UTC: EXPORT-SIDE MEMORY AMPLIFICATION (new in R5). exp-fat = the
  rung export with all 22 arrays replaced by 255 MiB sparse files (under
  MAX_ARRAY_BYTES 256 MiB, over each array's true length; manifest
  unchanged). r4-exp-fat (review CLI, light, cap 1.5 GiB): NO refusal;
  the cgroup sat at its 1.5 GiB cap (peak RSS 1.43 GiB) until the guard's
  60 s limit killed it (exit 75, child 143, empty log). r4-exp-fat-r4cli
  (the round-4 CLI ca736d48..., sequential loads): exit 1 in 0.28 s,
  "array `wq`: 267386880 bytes on disk, the manifest's dtype and shape
  give 147456", max RSS 264 MB. Measured under the cap with 40 MiB arrays
  (exp-fat40, 20:28): review CLI 471 MB RSS before the same refusal,
  round-4 CLI 44 MB [MEASURED, shared box, n=1] -> ~11 arrays resident at
  once instead of 1 (two layers x eleven parallel array loads, each read
  bounded only by the 256 MiB per-array constant, the length compared
  only after the read). Finding r4_A.
- 20:50 UTC: r4-test-build still waiting (queued 20:26). /proc/locks: the
  heavy lock (inode 36955) is held by pid 86262 = the native lane's
  r5-ladder8b-T128-cpu guard, itself waiting for 7 GiB of budget while the
  calibration lane's light jobs tl-v4-l22-dense-f (6 GiB, since 19:48, max
  3 h) and b5-b6_l1_perhead (4 GiB, since 20:26) hold 10.0 of 11.89 GiB
  (the known admission gap). Also queued for the heavy lock: gzc-stack-s0-
  base / s4-diag (gpu), r5-stack-verify (cpu), tio-c1-check (build).
  This r5b-test-build's measured peak was 2.88 GiB, so the 3 GiB
  declaration stays. Meanwhile: Layout's ten pub row fields are exactly
  the ones check_is_for_shape compares (the rest are private to layout.rs);
  every trained CLI path (prove, verify, stack-prove, stack-verify,
  controls) goes through the CS-6-checked run entry points.
- 21:23 UTC: r4-test-build exit 0 (admitted 21:15:58 after ~50 min in the
  queue; ~7 min). r4-fast (cpu 2/4 GiB, --test-threads=1): 9 passed, 0
  failed (r4/r4-fast.log):
  * r4_1 (r3_3 CLOSED): statement over A (two-block bound run, rung-TC),
    block 1 of B differs. Honest prover handed B: "ruling CS-6 — block 1
    ... refused before anything is absorbed", 0 witnesses asked, 0 segments
    sunk. A CHEATING prover (test switch) proves B under A (15,012,880 B);
    verify_run handed B: refused by CS-6 by name (round 3: ACCEPTED), also
    with the switch on in the verifier's thread; handed A: rejected ("M:
    mask: the product polynomial's sum != the combined functional");
    verify_run_from_dir with B from the real directory and from a missing
    one: CS-6; counts 1 and 3: CS-6 by name; honest A chain verifies.
  * r4_2: 9,672 cases (9,648 violating) at rung-G/P2/K4/TC, all six axis
    pairs: pre-scan verdict and first error == the round-3 loop.
  * r4_3: frozen rung-G and m125: every one of 35 field writes refused by
    CS-8/CS-9. Trained rung: check_constructed ADMITS in-class writes of
    norm_cn_a, norm_cn_m, norm_ceps, sh_ao, sh_s, sh_o, sh_h, sh_z (the
    door's inputs; derived fields, flags, axes, f_e, windows refused).
  * r4_4a: 5 TOCTOU cases between the digest pass and the SHA-free reload
    (array rewritten with its manifest SHA left stale x3 arrays; array +
    manifest with/without profile digests): every reload of the changed
    block refused (block digest, or manifest SHA vs profile.json).
  * r4_4b: 4 layers: parallel digest pass == sequential load_layer ==
    reload_block digests, records equal; first error in LAYER order in all
    3 cases (wk of layer 0 over wq of layer 1 in one chunk; layer 1 over
    layer 3 across chunks; layer 3 alone).
  * r4_4c: streaming CS-6: cache digest list swapped / consistent cache over
    swapped layers: verifier and prover refuse by CS-6's name, 0 asked, 0
    sunk, 0 block loads; the statement's list over swapped layers: the
    reload is refused; one block fewer: CS-6 count.
  * r4_4d: parallel pad_matrix == sequential at 4 shapes (Wq/Wo head map,
    Wk, gamma, Wg, Wd).
  * r4_4e (r4_B evidence): trained_block::read_bounded(max 4096) under a
    concurrent swap, 6,362 calls in 10 s: 340 returned MORE than the bound
    (largest 67,108,864 B = 16,384x the bound), 171 parked in a FIFO open
    (rescued by a non-blocking writer; without it, forever).
  * r4_5: run::read_segment_bounded under 1.8 M swaps over 7 candidates,
    105,316 reads: Ok only with the counted length (5,842 good + 17,648
    same-length other); refused by lstat type 29,067, lstat length 49,456,
    O_NOFOLLOW open 3,279, fstat after open 24; no unknown refusal; slowest
    call 5.6 ms; process VmHWM 189 MiB.
  The author's suite (r4-suite) is next in the queue.
- 22:12 UTC: r4-suite exit 0 (admitted 22:04:38 after 2,460 s in the
  queue; wall 444 s, peak RSS 4.25 GiB): the author's full release suite
  on the scratch copy with --skip review_r4: 29 targets, 688 passed, 0
  failed, 29 ignored (lib 543 / 0 / 29, 9 filtered out = my review tests)
  = the author's r5-suite2 counts. r4_queue.sh, r4_prove_checks.sh and
  r4_fat40.sh all wrote their done markers; no review job is live (ps).
  /tmp: 8 dirs /tmp/zk60-native-tiny-159633-* (37 MB, 22:05 UTC) fall in
  the suite's window but cannot be attributed with certainty (other lanes
  run the same tests), so they were left in place; the 153419 ones
  predate the suite. review_tmp/ is empty (my tests clean up).
- 22:13 UTC: R4_VERDICT.md final. VERDICT: the Round-5 changes are
  ACCEPTED on soundness; r3_3 CLOSED (r4_1), r3_6 CLOSED. New: r4_A
  (export-side memory amplification from the parallel array loads; verifier
  DoS, low-medium, new in R5; minimal fix: bound each array read by its
  exact length and check the manifest's dtype/shape against the code's
  before reading), r4_B (read_bounded lstat-to-read race in the export
  reader, low, pre-existing; fix: read_segment_bounded's open discipline).
  Notes N-r4-a..e. Round 4 closed; nothing of mine is running.
