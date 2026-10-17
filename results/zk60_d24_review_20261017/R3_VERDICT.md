# D24 review, round 3: verdict

Written 2026-10-17 18:3x UTC by the independent review lane (successor session
after the 18:21 UTC reboot). Reviewed code: the frozen copy
`ops/zkp-mvp/trained-1b-review-r3/` (195 files, re-verified against
`ops/zkp-mvp/trained-1b-review-r3.sha256` at 18:30 UTC, all OK), which is the
native lane's Round-3 + Round-4 tree, and the Round-4 production CLI
`results/zk60_1b_native_20261017/r4/zk60_trained_block.release.bin`
(sha256 ca736d48...). The full log is `PROGRESS.md` in this directory.
This is not a privacy acceptance; only Victor rules on those.

## Verdict

**The Round-4 Llama-3-8B profile changes are ACCEPTED on soundness.** One
finding stays open, r3_6: a malicious receipt can make the verifier run out of
memory or hang. That is a denial-of-service against the verifier. It does
not make the verifier accept anything false, so it does not block the
soundness acceptance, but it should be fixed before the stack verifier is
handed receipts from untrusted provers. r3_3 is closed by the native lane's
Round-5 CS-6 port as the code is written; the native lane's own R5 tests have
not run yet (`r5-suite-a` exit 70 at the 14:59 shutdown).

What was checked for each Round-4 item:

| Round-4 item | Evidence | Status |
|---|---|---|
| tn <= 9 at width 4096 | `NormCalibration::derive_at_width` (shape.rs:216) derives D_max = isqrt(ceps + 4096 * 32768^2): 2,097,152 at ceps 1 and at ceps 78,617, 2,344,687 at ceps 2^40. All are 22 bits, so tn <= 9 for the whole ceps class and 2 D_max < 2^24 [COUNTED]. My own no-wrap checker at 8B T32 puts every clause at the class extremes at or below 2^48.039 (norm C0), with down over f_pad 16384 at 2^36 (`reviewer_nowrap_r3.json`). The author's test refuses tn 10 by name; it passed in my run (r3-controls). | accepted |
| D_max for the new profiles | Derived per width by the door (`with_trained_calibration`, shape.rs:1230) and re-derived by `check_trained_class` in `Layout::for_shape`. A shape edited after the door is refused (r3_1, plus the F-1/F-5 checks from rounds 1-2). The 8B shape is built only through the door (shape.rs `llama3_8b_t32_at`). | accepted |
| RoPE base pinned per profile | `shape::trained_rope_theta` gives 500000 for 8B and 10000 for TinyLlama and the rung. `IntegerCalibration::check_honoured_by_code` refuses any other base, and the base is encoded in the statement (`rope-theta-f64-bits`). The RoPE tables themselves are in the block digest (`AttentionPublic::absorb_into`) and in the per-layer `table-k-sha256`. See note N-r3-a. | accepted |
| Checkpoint pinned per profile | `ModelSource::pinned_for_profile` covers TinyLlama x3 and Llama-3-8B (NousResearch/Meta-Llama-3-8B @315b2009, a canonical shard-list digest over 4 shards). The production `check_self` refuses any other source, and a synthetic recipe, at these profiles. The waiver exists only in test builds (`waived_for_tests` is `false` under `cfg(not(test))`). | accepted |
| 8B table digests | The author's `r4_tests` reproduce the calibration lane's RoPE (T32, hd 128, base 500000) and exp (f_e 9, e_s 1/2) digests. They were part of my r3-controls run: 99 passed, 0 failed, 10 ignored. The loader compares the exp/act/RoPE tables with their generators unless `--rope-from-export` is passed. | accepted |
| Statement binding | `TrainedModelStatement::encode` binds the block and run profile, the geometry (incl. kv-heads, log-cols), the source pin, the whole calibration incl. the RoPE base, and every layer's block digest, words and tables. `check_against` requires the run's block digests to equal the statement's. Fresh-process stack-verify of the author's 32-block 8B artifact with the r4 CLI: "verified", statement 259dad7c... (13:56). My 2-layer rung stack: honest verify plus 11 run-level controls, all refused (14:11). In r3 the library-level gap r3_3 remains; R5 closes it. | accepted |

## Findings

| id | what | severity | status |
|---|---|---|---|
| r3_1 | R2-a (a non-door shape under a trained profile string) | soundness (round-2 finding) | CLOSED in r3. Refused by `Layout::for_shape` and `single_block_profile_allowed` at f_e 50 and 12. A frozen rung-C6 edited to f_e 50 is refused by the universal softmax-window check. |
| r3_2 | Endpoint lies in a two-block bound run | soundness check | HOLDS. Input endpoint one word off: rejected at slot 21. Output endpoint one word off: rejected at slot 22. A different chain under the honest endpoints: rejected at slot 21. |
| r3_3 | CS-6 at the library level: `run::verify_run` accepts blocks B under a statement over blocks A when the prover and the verifier are both handed B. The run absorbs the statement's digests but checks the slots against the handed blocks. | soundness, latent at the library API. Not reachable from the r3/r4 production CLI: its `BlockCache` (trained_block.rs:1571) refuses any reload whose digest is not the statement's, and the cache and the statement are built from the same digest list. | OPEN in r3. CLOSED by the R5 port as written (see below). |
| r3_4 | TOCTOU between the stack digest pass and the per-block reload | soundness check | HOLDS. Refused in all 3 cases: manifest digest against profile.json, the BlockCache block-digest check, and array SHA against the manifest. |
| r3_5 | Production-CLI stack-verify of my 2-layer rung stack (statement 72098637...) | check | PASS. Verified, 15,012,880 B, VmHWM 30 MiB. All 11 run-level controls refused, and the honest receipt still verifies (`r3-stack2-verify.log`). |
| r3_6 | **The stack verifier reads each segment file with no bound** | **verifier DoS (memory exhaustion or hang), not soundness**. Medium: on an uncapped host one crafted receipt can drive the system OOM killer. | **OPEN.** Also present in the native R5 tree (run.rs:1255, trained_block.rs:2119, read 18:3x UTC). |
| N-r3-a | With `--rope-from-export` (an operator opt-in) the bound RoPE tables may differ from the generator at the profile's pinned base, but the statement's `rope-theta` field still says the pinned base. The tables are bound by the block and table digests, so the statement identity is exact, but the base field can mislead a reader. | note (labelling) | Suggest refusing `--rope-from-export` at the pinned-checkpoint profiles, or binding a "RoPE tables from export" field. Not new in Round 4. |

### r3_6 in detail

- **Path:** `stack-verify` goes `stack_verify_inner` (trained_block.rs:1976) → `run::verify_run_from_dir_with` (run.rs:1057-1070) → `std::fs::read(p)` for each `segment-NNN.bin`.
  - There is no file-type or symlink check and no ceiling.
  - The file length is never compared with the verifier's own counted length `wire::segment_len(&st.stage_layout(k)?, st.seg_geom(k)?)`, although that length is known before the read.
  - The length is compared only in `wire::decode_segment` (wire.rs:438-442), after the whole file is resident.
  - `run_sink::segment_paths` (run_sink.rs:90) checks entry names only.
  - `statement/segments.json` is never read by the verifier. That is correct: it is prover-written, and the bound must be the verifier's own counted length.
  - `--controls` also reads all L segments with an unbounded `fs::read` (trained_block.rs:2021).
  - The single-block `verify` is NOT affected: it uses `read_bounded` (trained_block.rs:1355 and :294), which refuses symlinks, refuses anything that is not a regular file, and checks len <= 256 MiB before reading.
- **Evidence:** all runs used the r4 CLI, light class, under the guard.

  | case | result |
  |---|---|
  | `r3-stack2-dos`: segment-000.bin is a symlink to `/dev/zero` | exit 137 after 0.77 s: killed by the 1.5 GiB kernel cap while reading. Empty log. |
  | `r3-stack2-sparse`: a 512 MiB sparse regular file | exit 1, "segment 0 is 536870912 B, the counted length is 7398936": the whole file was read before the check. |
  | `r3-stack2-sparse-time`: the same file under `/usr/bin/time -v` | maximum RSS 527,448 KiB [MEASURED, shared box, n=1] for a 15 MB honest receipt. |
  | `r3-stack2-fifo`: a FIFO | blocks in open() forever; killed by the guard's 20 s limit (exit 75). |

- **Minimal fix** (run.rs `verify_run_from_dir_with`, replacing the `std::fs::read(p)` line; the same bounded reader is needed in `stack_controls`):

  ```rust
  let want = wire::segment_len(&st.stage_layout(k)?, st.seg_geom(k)?);
  if want > wire::wire_ceiling(&st.rs.sh) {
      return Err("private run wire: segment exceeds bound".into());
  }
  let meta = std::fs::symlink_metadata(p).map_err(|e| format!("private run: segment {k} ({}): {e}", p.display()))?;
  if !meta.file_type().is_file() {
      return Err(format!("private run: segment {k} ({}) is not a regular file", p.display()));
  }
  if meta.len() != want as u64 {
      return Err(format!("private run wire: segment {k} is {} B, the counted length is {want}", meta.len()));
  }
  let f = std::fs::File::open(p).map_err(|e| format!("private run: segment {k} ({}) cannot be read: {e}", p.display()))?;
  let mut bytes = Vec::with_capacity(want);
  std::io::Read::read_to_end(&mut std::io::Read::take(f, want as u64 + 1), &mut bytes).map_err(|e| format!("private run: segment {k}: {e}"))?;
  // decode_segment re-checks bytes.len() == want (a file that changed after the stat)
  ```

  The `take(want + 1)` caps the read even if the file is swapped or grows after the stat. Opening with `O_NOFOLLOW | O_NONBLOCK` would also close the narrow lstat-to-open race to a FIFO. Suggested regression test: a run directory whose segment 0 is (a) a symlink to /dev/zero, (b) a FIFO, (c) a sparse file one byte over the counted length. Each must be refused by name, with the "counted length" or "not a regular file" text coming from metadata, before any segment byte is read.

### r3_3 and the native lane's Round-5 CS-6 port

I read the port in `ops/zkp-mvp/trained-1b/` without running anything. The tree is live; at the time of reading, run.rs had sha256 8f6f0d04... and trained_block.rs c3c60f6b.... **As written, the port closes r3_3.**

- `RunVerifier::start` (run.rs:1004) calls `blocks.are_the_statements(st)` before the run header is absorbed, and it never consults the cheating-prover switch. Every verifier entry point goes through `start`: `verify_run`, `verify_run_with`, `verify_run_from_dir`, `verify_run_from_dir_with`.
- For a resident slice, `blocks_are_the_statements` (run.rs:806) checks that the count is L and that `blocks[k].digest() == st.block_digests[k]` for every k.
- `BlockPublic::digest()` is recomputed from every field the verifier reads (wq, wk, wv, wo, gamma_a, rope_cos/sin, exp, gamma_m, wg, wu, wd, act). There is no cached digest to desynchronise.
- For the streaming `BlockCache` (trained_block.rs:1657), the digest list it enforces on every reload is compared entry by entry with `st.block_digests()`.
- `prove_run_with` makes the same check unless the test-only cheating switch is on.
- `cs_port_tests::cs6_the_run_prover_and_verifiers_refuse_blocks_that_are_not_the_statements` covers the one-block form. The two-block form (block 1 differs, as in my r3_3) goes through the same per-k loop.
- **Caveat:** that test has not been run yet (`r5-suite-a` never started). The R5 reload now skips the per-array SHA-256 and relies on the block-digest comparison. That is sound for statement binding, but it is outside r3 scope and belongs to a later review round.

## Evidence (this directory)

`PROGRESS.md`; `reviewer_nowrap_r3.py/.json`; `r3-fast.*`, `r3-controls.*`, `r3-8b-fresh-verify.*`, `r3-art.*`, `r3-stack2-verify.*`, `r3-stack2-dos.*`, `r3-stack2-sparse.*`, `r3-stack2-sparse-time.*`, `r3-stack2-fifo.*`; `r2-vs-r3.patch`. Scratch: `ops/zkp-mvp/trained-1b-review-r3-scratch/` (review tests `review_r3_tests.rs`, `review_r3_inner`/`review_r3_artifact` in `trained_block.rs`; `review_out/stack2/{rev-stack2,run,run-dos,run-sparse,run-fifo}`. `run-fifo/segment-000.bin` is a named pipe; `run-sparse/segment-000.bin` is a 512 MiB sparse file that uses no disk blocks).
