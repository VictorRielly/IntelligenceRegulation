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

## ROUND 5 (re-review of the native R5b tree, ops/zkp-mvp/trained-1b-review-r5/)

- 00:07 UTC (2026-10-18): opened on the coordinator's relay. Read the native
  ledger's R5 tail and R5b section (PROGRESS 1060-1440) and the privacy
  review's P-1..P-7 (REVIEW.md 40-100, 315-520).
- 00:08 UTC: copied r5b/frozen-tree/ (218 files, no target dirs) to
  ops/zkp-mvp/trained-1b-review-r5/; ops/zkp-mvp/trained-1b-review-r5.sha256
  (218 entries) equals r5b/manifest_frozen.json file for file; tree hash
  recomputes to 44013397... = FROZEN.txt. r4-vs-r5.patch (my R5 copy ->
  R5b copy) = 2,099 lines = the author's r5b-vs-r5.patch length; 14 files
  (trained_block.rs +504/-195, ladder8b_tests.rs new, shape.rs, run.rs,
  trained_block_tests.rs, trained_stack_tests.rs, run_capture.rs, run_tests,
  s24_tests, mvp_driver, examples/zk60_trained_block.rs, trained_calib_tests,
  trained_statement.rs, private_block.rs).
- 00:08-00:16 UTC: read every non-test hunk of r4-vs-r5.patch. Code-read
  results: (P-1 a / H-1) seal_and_record runs the full checked load + digest,
  the witness builder from the previous output and parity at EVERY layer,
  and the block-0 input check, BEFORE prepare_endpoints / create_dir; the
  endpoints are the builder's planes; builder refusals name the check only.
  (P-1 b / M-9) default: the prover writes <out>.unverified-statement/ (+
  UNVERIFIED.txt); stack-verify promotes by RENAME after verification, having
  checked only three substrings of statement.json (identity, context,
  expected_io) and segments.json against a RE-READ of the segment files.
  (C-R4) label_of on all four CLI entries, allow-list = the defaults; flags()
  takes the FIRST of duplicate flags (no bypass). (C-R1) c_r1 on both context
  digests. (P-5) refuse_prover_private_entries on both verifiers (top-level
  "seq_*" names). (P-6) PARITY_REFUSAL without count/position/value; the
  stack names the layer; load_seq_dir errors generic. (P-7) backend,
  gpu_declines, prover_verified_in_process in statement.json (prover self-
  reports). (r4_A) load_array_checked: manifest dtype/shape vs the code's
  expected alternatives BEFORE the read, n <= MAX_ARRAY_BYTES, read with the
  EXACT length. (r4_B) run::read_regular_file_bounded (lstat type/length,
  O_NOFOLLOW|O_NONBLOCK, fstat re-check, take(max+1), length re-check) backs
  trained_block::read_bounded and mvp_driver's reader + segment scan.
  (8B T64/T128) new block + run strings, llama3_8b_log_cols 13/14,
  trained_geometry entries, Shape::llama3_8b_trained (refuses other T),
  Geometry::Llama3_8B(T) in the reader (T 32/64/128; shape_for refuses a T /
  geometry mismatch), every registry uses the generic lists
  (TRAINED_CALIBRATION_PROFILES 7, LLAMA3_8B_TRAINED_PROFILES 3, CS-7 map,
  RunShape::tinyllama_trained map, RunStatement::new refusal list, pinned
  source, RoPE 500000); the softmax top-limb pins (layout.rs 707-708:
  scaled(top, 2^(8 ls - wrho_s)), scaled(pl_top, 64)) bound sr, sg < 2^wrho_s
  and p < 2^10.
- 00:16 UTC: reviewer_nowrap_r5.py (light, exit 0, r5/r5-nowrap.log, json):
  8B T32/T64/T128, every f_e 9..=16, whole shift windows: T128 f_e 16 c2
  2^33.0, c3 2^24.0, PV accumulator 2^24, PV host 2^24.6; T64 c2 2^32, PV
  host 2^24.0; Sum - 1 < 2^wrho_s at every (T, f_e); geometry hosts <= 2^36
  (down over f_pad 16384); norm at width 4096 T-independent (r3: C0
  2^48.039, tn <= 9).
- 00:17 UTC: scratch ops/zkp-mvp/trained-1b-review-r5-scratch/ (r5 copy +
  review modules: review_r5_inner in trained_block.rs [r5_1 export reader
  race, r5_3 promotion attacks], review_r5_tests.rs [r5_5 8B profiles];
  write_stack_export pub(super)); my verifier copy of the calibration lane's
  llama3_8b_pg_rot1_b6_T128 export (hard links, seq_* excluded, 454 files)
  at verifier-8b-T128/; fixtures r5/make_fixtures_r5.py (verifier copies
  without seq_*; fat / zero / FIFO / big / misdeclared arrays, FIFO
  profile.json, /dev/zero manifest, FIFO expected.bin).
- 00:18 UTC: launched r5/r5_queue.sh (detached, serial, each leaf guarded).
- 00:20 UTC: r5-cli-build exit 0 (pristine frozen copy -> scratch
  target-cli, ~2.7 min); review CLI r5/zk60_trained_block.review-r5.release.bin
  sha256 2dcf76d0... (r5/binaries.sha256). Probes 00:20:52-00:20:59, each
  guarded light 0.5/1.5 GiB (1.5/1.5 for the fat ones) [MEASURED, shared box,
  n=1]:
  * P-5: a verifier export holding seq_s0 -> "privacy review P-5: ... holds
    the prover-private entry \"seq_s0\"". C-R4: stack-verify --label
    request-42 and stack-prove --label request-42 refused by name; the prover
    created neither the run dir nor the unverified dir.
  * honest (verifier copy, round-3 run with statement/): verified, 11
    controls refused, 41 MiB.
  * r3_6 probes on R5b (unchanged reader): /dev/zero, 512 MiB sparse, FIFO,
    1 B short/long, directory, /dev/null, symlink-to-honest, segment-1 FIFO
    (+ --controls): all refused by name, 0.02-0.26 s, 10-30 MiB; hard link
    verifies; statement/expected.bin a FIFO -> "not a regular file ...
    refused before it is opened".
  * r4_A / r4_B (verifier): wq a /dev/zero symlink or a FIFO -> "layer 1:
    array `wq`: ... not a regular file ... refused before it is opened";
    300 MiB -> "314572800 bytes on disk, the expected length is 147456;
    refused before it is read"; profile.json a FIFO and a manifest a /dev/zero
    symlink -> "not a regular file"; wk misdeclared [384, 384] -> "the
    manifest declares I8 [384, 384], expected one of [(I8, [128, 384])]
    (refused before it is read: review r4_A)"; exp-fat40-v and exp-fat-v
    (22 sparse 40 / 255 MiB arrays) -> refused at layer 0 wq from metadata in
    0.00 s, max RSS 3.7 / 4.0 MiB (round 4: 471 MB / 1.43 GiB at the cap
    until killed). Prover side: stack-prove on the fat export (with seq_s0)
    -> refused in the sealing pass before any read, 3.8 MiB, no run dir.
    r4_A and r4_B CLOSED at the CLI.
- 00:28-00:30 UTC: r5-8b-T128-verify (cpu 1.5/3 GiB, RAYON 16): the review
  CLI, in a fresh process, from MY verifier copy of the calibration lane's
  ORIGINAL export (hard links, no seq_*), of the native lane's 32-block
  Llama-3-8B T128 run (r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu/run,
  read only: its statement/ already exists, so nothing is promoted or
  written): "verified", 32 blocks, 922,711,264 B, statement identity
  6aba46fbd12d14b0... rebuilt from the original export = the pin; load 14.7
  s, verify 38.5 s (block loads 17.7 s); all 11 run-level controls refused
  (f_e + 1 by the counted length: the T128 layout moves with the sigma_s
  limbs); honest still verifies; wall 166.6 s, max RSS 2.34 GiB [MEASURED,
  shared box, n=1].
- 00:33-00:34 UTC: r5-test-build exit 0 (--lib --no-run, ~2.7 min); r5-fast
  (cpu 2/4, --test-threads=1) 3 passed, 0 failed (r5/r5-fast.log):
  * r5_5: 8B T64 and T128 at every f_e 9..=16 and two calibrations (the
    R4 test constants and the R5b export's) build through the door with
    wrho_s = log2 T + f_e, log_cols 13 / 14, 37 endpoint rows, a layout and
    CS-8; counted A 3229 / H 3534 / 21,697,512 B (T64) and A 3405 / H 3790 /
    29,300,856 B (T128) at f_e 9; f_e 8 and 17 refused; T 16/33/96/256
    refused; every other trained run profile refuses each shape (CS-7); each
    block string at the other T's geometry refused (CS-9 as a release build)
    and by CS-8; a TinyLlama geometry under the 8B string refused (CS-8); 14
    trained block/run strings pairwise distinct (D17); T64/T128 in the door
    list, RoPE 500000, pinned checkpoint.
  * r5_1 (r4_B re-run): read_bounded(max 4096) under a concurrent swap
    (4 KiB file / 64 MiB sparse / symlink to it / /dev/zero symlink / FIFO):
    5,841,763 calls in 10 s, Ok only with the regular file's bytes
    (1,472,702), 0 other returns (round 4: 340 over-bound, 64 MiB); refusals
    3,022,981 lstat type, 969,872 lstat length, 197,729 O_NOFOLLOW open,
    178,479 fstat after open; slowest call 4.9 ms. (15 non-blocking writer
    opens of the FIFO succeeded: the reader holds an O_NONBLOCK fd for
    microseconds before fstat refuses it; a blocking park is impossible with
    O_NONBLOCK, and none of those calls returned data.) r4_B CLOSED.
  * r5_3 (P-1 b promotion under attack), 2-layer rung stacks proved by the
    R5b stack-prove (default, no in-process verify):
    (a) the prover writes only <run>.unverified-statement/; a FAILED
        verification (segment byte flipped) promotes nothing. HOLDS.
    (b) the race at its point: run A verified; then segment 1 replaced by
        run B's segment 1 (same counted length, other transcript) and A's
        unverified segments.json rewritten to name it; promote_statement
        ACCEPTS; A has statement/; a fresh stack-verify of A afterwards
        fails (exit 1). The promotion binds segments.json to a RE-READ of
        the files, not to the bytes the verification consumed.
    (c) NO race needed: the prover's statement.json with false "scope",
        "backend", "blocks" and a DUPLICATE "trained_statement_identity" of
        zeros after the real one, plus an extra file EXTRA-prover-file.txt:
        an ordinary stack-verify exits 0 and PROMOTES both (only three
        substrings of statement.json are checked; the directory is renamed
        whole).
    (d) <run>.unverified-statement a SYMLINK to a directory elsewhere:
        stack-verify exits 0, <run>/statement becomes that symlink, and the
        marker inside the symlink's target is deleted.
    Finding r5_A (M-9 / D12b(1) publication integrity; not verification
    soundness: stack-verify never trusts statement.json).
- 00:34 UTC: r5-author-subset (cpu 4/6, the author's tests of the touched
  modules on my binary: trained_block_tests, trained_stack_tests,
  review_r4_b, review_r3_6, cs_port_tests, ladder8b_tests, s24_tests,
  s25_tests, trained_calib_tests, review_d24_tests, r4_tests; review_r5
  skipped): 64 passed, 0 failed, 9 ignored (heavy), incl. the layer-1
  parity refusal with no run dir, the P-1/P-3/P-5/P-6/P-7 CLI tests, r4_A /
  r4_B regressions, the 8B T64/T128 counted layouts and no-wrap tests, the
  N-r4-d capture pins, the s25 census. Removed only the 9
  /tmp/zk60-native-tiny-250615-* dirs created 00:34:00-00:34:20 UTC (inside
  that job's window, while it held the heavy lock). r5_queue.sh done; no
  review job live (guard status).
- 00:37 UTC: R5_VERDICT.md written. VERDICT: R5b ACCEPTED on soundness;
  the Llama-3-8B T64 / T128 profiles ACCEPTED (no-wrap, counted layouts,
  registries / D17, door classes, CS-7 / CS-9 cross pairs, export T mapping;
  the real 32-block 8B T128 stack verifies in a fresh process from my own
  verifier copy, identity 6aba46fb..., 11 controls refused). r4_A, r4_B
  CLOSED. P-1: H-1 holds; M-9 holds for the honest prover, but NEW finding
  r5_A (medium, publication integrity, not verification soundness): the
  promotion renames prover files checked by three substrings and a re-read
  of the segments -> a post-verify segment swap, a forged statement.json
  (+ duplicate identity key), extra files and a symlinked directory are all
  promoted (r5_3 b/c/d); minimal fix in the verdict (the verifier writes
  statement/ from its own data and the hashes of the bytes it verified).
  C-R4 / P-5 / P-6 / P-7 as described (notes N-r5-a..d). Round 5 closed;
  nothing of mine is running.

## ROUND 6 (re-review of the native R6 tree, ops/zkp-mvp/trained-1b-review-r6/)

- 02:37 UTC (2026-10-18): opened on the coordinator's relay. Read the native
  ledger's Round 6 section (PROGRESS 1476-1580).
- 02:38 UTC: copied r6/frozen-tree/ (219 files) to
  ops/zkp-mvp/trained-1b-review-r6/; ops/zkp-mvp/trained-1b-review-r6.sha256
  (219 entries) equals r6/manifest_frozen.json; tree hash 83f1fdcb... =
  FROZEN.txt. r5-vs-r6.patch = 1,610 lines = the author's r6-vs-r5b.patch;
  11 files (trained_block.rs +370/-90, trained_stack_tests +250, r6_tests.rs
  new, run.rs, protocol.rs, shape.rs, trained_statement.rs, ...).
- 02:38-02:42 UTC: read every non-test hunk of r5-vs-r6.patch. Code-read
  results: (r5_A) verify_run_from_dir_hashed_with returns (length, SHA-256)
  of exactly the bytes each step verified; stack-verify: check_statement_dir
  (real dir, symlink refused, exactly the named regular files) before any
  read; expected.bin read once and must be canonical; after the verify (and
  controls) the found statement.json must be byte for byte the verifier's
  render_stack_statement with the writer and prover claims it names (strict
  parse; writer must be Unverified for an unverified dir, InProcess /
  FreshVerify for statement/), segments.json must equal the verified hashes;
  publication writes a fresh statement.writing-<pid> (create_dir), checks
  the target is absent, renames, removes tmp on failure; the prover's
  unverified dir is re-checked as a real dir before remove_dir_all (which
  does not follow a top-level link). In-process path: verified hashes must
  equal the sink's. Schema /2: statement_written_by + prover_reported
  {backend, gpu_declines, what} (N-r5-c, also the block statement).
  (per-layer sh_s) loader: profile_constants nulls must equal
  per_layer_constants_differ; with sh_s listed and no uniform profile
  constants the run base = the mode over the run's layers (ties: smaller);
  load_layer_mode compares every other constant with the run's and records
  an own sh_s (Some only when != base) after Shape::with_score_shift
  (trained shapes only, ONE_LIMB_SHIFT window, CS-8 rebuild, trained class);
  LayerRecord.sh_s encoded as "sh-score-layer" only when present (run-wide
  identities unchanged), check_self refuses own == base or outside the
  window; RunStatement::new_bound_from_digests re-validates each own value
  at the door (prover and verifier both build it) into stage_sh_s; the
  stage schedule line carries "score shift v (the layer's own; the run's is
  b)" only when it differs; stage_layout, prove_core and verify_core run at
  stage_shape(k); the sealing pass builds each witness at its stage shape
  and runs protocol::check_lookup_misses on it (N-r5-a); rebuilds use the
  sealed shapes. sh_s enters one relation (the score host) and one lookup
  coefficient (scaled(rsl, 2^(8 - sh_s))). (N-r5-d) prover_start event;
  scope texts updated.
- 02:43 UTC reviewer_nowrap_r6.py (light, exit 0; json): score host over
  sh_s 1..=8 <= 2^20.022 (head_dim 64) / 2^21.0 (head_dim 128); round 5's
  full clause set at TinyLlama T32/T64/T128 (worst 2^35; T128 f_e 16: c2
  2^33, c3 2^24, PV host 2^24.6) and 8B T32/T64/T128 (worst 2^36).
- by 02:43 UTC: scratch ops/zkp-mvp/trained-1b-review-r6-scratch/ (r6 copy +
  review_r6_inner in trained_block.rs: r6_1 writer attacks, r6_2 per-layer
  export attacks, r6_3 CS-3 sealing check; write_stack_export /
  write_stack_export_with pub(super)); my b7 T128 verifier copy (hard links,
  no seq_*, 454 files) at verifier-8b-b7-T128/. The calibration lane's b7
  T128 export: profile sh_s null, per_layer_constants_differ [exp_e_s, sh_s,
  silu_member], layer 1 at 7, 31 layers at 6, 32 manifest digests pinned,
  profile sha256 040eb5cf.... The native lane's b7 stack has NOT landed
  (its run dir is empty; the prove waits in the guard).
- 02:44 UTC: launched r6/r6_queue.sh (detached, serial, guarded).
- 04:22 UTC (2026-10-18): resumed after the usage-limit stop (~03:17 UTC)
  on the coordinator's relay. r6_queue.sh had finished by itself at
  03:20:45 (markers present; no job of mine live; heavy lock free). r6
  frozen copy re-verified unchanged (219 OK). Results of the queue:
  * 03:16 r6-cli-build exit 0: review CLI r6/zk60_trained_block.review-r6.
    release.bin sha256 46a949f6... (r6/binaries.sha256).
  * run-wide export keeps its identity under R6: r6-runwide-prove (R6 CLI,
    default = no in-process verify) printed 72098637... = round 3's; prove
    wrote only <run>.unverified-statement; r6-runwide-verify --controls
    verified, 11 controls refused, "statement-published ... by stack-verify,
    from its own rendering and the hashes of the verified bytes", the
    prover's dir removed; r6-runwide-recheck: "statement-checked ... byte
    for byte this verifier's rendering of the verified run".
  * r6-8b-b6-under-r6 (exit 1, EXPLAINED, not a loader fault): the R5b-
    proved run-wide 32-block 8B b6 T128 run, read only, from my round-5
    verifier copy: "verified", identity 6aba46fb... UNCHANGED under R6
    (load 12.6 s, verify 33.4 s, 2.1 GB); then refused at the r5_A
    byte-check of its EXISTING statement/, which R5b wrote under schema
    /1 ("statement.json: not schema zk60-trained-stack-run/2 (review
    r5_A)"). That is the intended rule (an older writer's statement/ is
    refused, never trusted); the native lane re-lays such statements
    (r6_compat_prepare.py). Note N-r6-c.
  * r6-8b-b7-identity (exit 1, EXPLAINED): a deliberate zero pin so the
    CLI prints the identity it rebuilds from MY verifier copy of the
    calibration lane's per-layer b7 T128 export: 97c4acda9da994c1... (the
    loader accepts the real per-layer export; no artifact needed before the
    pin check). The native lane's b7 stack has not landed (run dir empty at
    03:17 and at 04:22).
  * 03:20 r6-test-build exit 0; r6-fast (my review tests, cpu 2/4,
    --test-threads=1): 3 passed, 0 failed (r6/r6-fast.log):
    r6_1 writer attacks: (b) swap + rewritten segments.json after the
    verify: refused, nothing published; (b') swap alone: published
    segments.json names the VERIFIED bytes, a later verify of the swapped
    dir fails; (c) duplicate keys + false scope, writer label InProcess /
    FreshVerify inside an unverified dir, a non-canonical JSON escape, a
    300-char backend, one trailing space: each refused, nothing published;
    (c') a canonical but false backend claim is published under
    prover_reported (by design, labelled); (d) symlinked unverified dir:
    refused, the target's marker intact; (d2) a published statement/
    replaced by a symlink to an identical copy: refused; (e) a leftover
    statement.writing-424242/: the run refuses to verify at all (note
    N-r6-b); (f) a PROVER-written statement/ naming stack-verify as its
    writer, canonical otherwise: accepted at the byte check (exit 0) after
    a full verification (note N-r6-a: the writer label is not
    authenticated); (i) both dirs: refused; (k) two concurrent
    publications of one run: exits 0 / 1, no leftover writing dir, a third
    verify checks byte for byte.
    r6_2 per-layer export attacks (rung-TC 3-layer export, layer 1 at 6,
    base 5): honest proves, verifies with controls, publishes; layer 1 at 9
    or 0 (re-pinned), base 9, profile sh_s non-null while listed, null but
    unlisted, a stale manifest digest, a run-level constant (sh_o) differing
    in one layer: verifier statement refused AND stack-prove refused with
    no run dir; layer 1 at 7 re-pinned: another identity, the run proved at
    6 refused under it (binding); tie {6,5}: base 5, layer 0 own 6,
    verifies; sub-range --layers 1..2: base 6, no own record, verifies,
    identity differs from the full range.
    r6_3: check_lookup_misses refuses an exp miss and an act miss by CS-3's
    name with the family only.
  * r6-author-subset (the author's tests of the touched modules on my
    binary): 72 passed, 0 failed, 9 ignored, incl. r6_tests (6), the
    per-layer stack test and review_r5_3.
  Removed only the 11 /tmp/zk60-native-tiny-368286-* dirs of my author-
  subset run (pid dead, inside its 03:20:11-03:20:45 window).
- 04:24-04:25 UTC: two variants of my b7 verifier copy (make_b7_variants.py:
  hard links, the two edited files fresh copies; the original export's
  profile.json sha256 040eb5cf... re-checked untouched), each a guarded
  cpu 3/5 digest pass of my CLI with a zero pin: `flat` (layer 1's sh_s
  7 -> 6, profile re-pinned) rebuilds identity d29c4343... != the per-layer
  export's 97c4acda... (11.3 s, 2.0 GB); `shs9` (layer 1 at 9, re-pinned)
  refused at the door before any array is read: "layer 1's own sh_s: ...
  a per-layer sh_s 9 is outside its structure-preserving window 1..=8"
  (0.6 s). (queue.out's "exit 0" lines for these two are a wrapper
  artefact — `$?` read after a command substitution; the .done files and
  guard JSON hold the real codes, 1 and 1.) The native lane's r6_stack.sh
  for b7 T128 is still live (its prove waits in the guard); not landed.
- 04:2x UTC: R6_VERDICT.md written. VERDICT: R6 ACCEPTED on soundness.
  r5_A CLOSED (writer attacks (b) (b') (c) (d) (d2) (e) (i) (k) all
  refused or correct; (c') and (f) by design); per-layer sh_s ACCEPTED
  (format, door on both sides, binding incl. the real b7 export, class-wide
  no-wrap at all six profiles, run-wide identities unchanged incl. 8B b6
  T128); N-r5-a/c/d CLOSED; the two exit-1 jobs explained (schema /1
  statement refused after a successful verify; a deliberate zero pin).
  Notes N-r6-a (writer label unauthenticated), N-r6-b (leftover writing
  dir blocks verifies), N-r6-c (R5b statement/ needs re-layout), N-r6-d
  (queue.out artefact), N-r6-e (prover claims labelled). Round 6 closed;
  nothing of mine is running.
