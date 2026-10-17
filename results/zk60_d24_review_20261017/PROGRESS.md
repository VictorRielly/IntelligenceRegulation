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
