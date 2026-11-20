# Second cross-review: Sol's D78 package 255 (and the 229/238/242/248 chain)

Reviewer: Claude (Sonnet 5.5), 2026-11-16. Read-only on Sol's directory. Scratch: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/sol-review/` (`trace254.py`, `rerun254/`, `rerun254_corrupt/`). CONFIRMED = I ran or computed it; READ = code or reports only. Package 255 was the latest at review time; no newer package was seen.

## Verdict

Package 255 is supported with corrections, for its stated conditional scope (public synthetic saved rung, source snapshot tied by manifest hash, not a commit). The headline claim holds: 254's replay no longer reads any captured program graph, hosts, private descriptors, plane index, draw counts or H sums as expected values, and it reproduces exactly. The corrections are wording and disclosure: "independently evaluated from source" hides that the port is specialised to the LowH24 rung with caller-supplied constants, and Sol's seals now pin reviewer files.

## Findings

No High findings.

**Medium**

1. "Independently evaluated from source" is specialised and caller-parameterised (READ plus CONFIRMED). `d78_block_polynomials250.py:155-162` hard-codes the product shift 16 (65536 / 32768), the fix for the earlier `product6` mistake. Norm constants cn_a = cn_m = 4000, ceps = 1 are typed in by the caller (`probe_source_definition_integration254.py:100`, `probe_block_polynomials251.py:21`; the Rust tests use the same numbers, `range16_tests.rs:49`). `d78_block_public252.py:38-39,112` accepts only the exact rung profile with gate_shift 18 and wrho_s 17. The compact (`feature_pieces`) path is not exercised, because the rung has none. 255 `remaining` says "generic compact" only. The claim sentence should say "for the LowH24 noncompact rung with pinned fixture constants".
2. Reviewer files are inside Sol's seals (CONFIRMED). The 255 pins include the absolute paths of my `SOL_D78_REVIEW_212_222.md` and the two scripts under `sol_d78_review_scripts/`. `audit_review_corrections237.py:37-45` runs an instrumented copy of my `trace_controls.py`. The seal breaks if I edit that report, and part of Sol's evidence is produced by reviewer code. This is a process and independence concern, not a technical one.

**Low**

3. `assert` remains at `probe_source_definition_integration254.py:141,149` (claim comparisons). Both are redundant with derived claims used in `verify_opening` (`d78_capture_chain234.py:92`), but they vanish under `python -O`. The 4815 check is now `require` (254:176) (READ).
4. The integrated 254 has only one in-flow control (late end tag, 254:164-171, atomic). The derived-host, public-table and graph-removal paths are covered by component probes, not in situ. Sol did not test on-disk graph corruption (I did, below).
5. Public-table "provenance" is hand-transcribed from `fx_d78_rung`, `range16_tests::case(seed,2)` and `grow_tests::tame_case` (`d78_block_public252.py:36-99`, floats via Python `math`). Only the EXP, RoPE and SiLU words (10,496) are cross-checked against compiled native functions (`probe_block_public253.py:29-45`). The other tables are validated only by elementwise equality with the capture (1,975,296 cells). That is strong evidence the recipe equals what native produced, but it is not a mechanical extraction from the Rust test source.
6. 113 unpinned extra files (including a named pipe) remain in `source-d78-188/`. 237 lists them by metadata only and does not remove them. Capture `source_commit` is `uncommitted-test` and `proved_on_gpu: true`; 255 `scope` states the commit point and 237 says the GPU flag is annotation only.

## 1. Pins (CONFIRMED)

203 pins in 255: 0 mismatches, 0 missing, 0 symlinks. 341 source manifest files: 0 bad. The BLAKE3 module `d78_blake3_primitive184.py`, `d78_blake3_worker183.rs`, `d78-blake3-probe183/worker`, `probe_blake3183.py`, `D78_BLAKE3_PRIMITIVE_183.json` and the blake3 rlib are now direct pins, and the independent reference output is pinned. Every local module imported by any pinned `.py` is itself pinned (69 pinned `.py`, 0 unpinned imports). Empty-hash logs (13) are 0-byte rustc or stderr logs of the small native harnesses, as before.

## 2. The five corrections

1. Block host coefficients: **yes.** `d78_block_hosts232.py:13-69` derives the draw positions from a source draw plan (`host_draw_plan`), then takes the nu draws from `definition_challenges`, applies B2 batch weights and S row replication, and builds the host list. `:67` compares the capture's `hosted` against the derived list (not against itself). 254 passes `plans[k]["hosts"]` (254:116,121-122), and `d78_capture_chain234.py:84` hands those to `replay_slot`, whose `hosted` check is against the derived value. `d78_mask_functionals203.py:33` also gets the derived list. The draws are authenticated by the FS replay (`replay_definition`, `d78_public_transcript186.py:190`). I altered a captured coefficient: refused at "source-derived block host coefficients" (CONFIRMED). Token hosts: `d78_token_hosts235.py`.
2. 15 / 40 wording: **yes, with Finding 1.** 255 scope and `review_corrections` separate the cases, and both are now claimed as source ports.
3. BLAKE3 pins and shared-crate disclosure: **yes** (255 scope; `d78_capture_chain234.py:5-6`; direct pins).
4. Per-control reasons: **yes.** Every refusal in 237 (174), 240 (420), 244 (1,128), 251 (362), 253 (126) and 254 is recorded with exception type and message. The new 237 control (token support table with a recomputed digest and identical MLE) is recorded as refused at "derived token public table" (`audit_review_corrections237.py:62-75`, READ). I ran the equivalent block-table control three times: it reaches the derivation check (below).
5. The lows: **partly.** 236 and 254 use `require` for 4815 and have a late-tag control (yes). The 113 files are listed but not pinned or removed (partly). The `source_commit` note is in the 255 scope (yes). Asserts remain (Finding 3).

## 3. Graph-free replay (254)

Captured block graphs: `argument.pop("program")` runs on all 40 block arguments in memory (254:66-69), before any consumer; `require(removed_graphs==40)` at :175 (CONFIRMED by read and run). The capture on disk is unchanged and is still parsed and hash-checked by `load_capture`. Corruption test (CONFIRMED): in a scratch copy I changed the first term's coefficient of all 40 captured `program` graphs, and updated the manifest digests so the generic file hash passed. 254 still passes with the identical counter 4815 and terminal state. Without the manifest fix it would be refused by the generic capture digest check.

Still taken from the capture and used (READ): prover content (terminals, rounds, scalar, `c`, `mask_eval`, `sumcheck_final`, roots, PCS claims and columns, MLE values); `definition_challenges`, `batch_weights`, `batch_point`, `logup_challenges`, `r_emb` (authenticated by the FS replay); table `eq` points and public table values (checked against derivation, `d78_block_tables249.py:115-135`, `d78_block_public252.py:111-126`); `terminal_polynomial` (compared against the derived expression, `d78_block_polynomials250.py:191`, then replaced by the derived value in the functionals, 254:121-122); `public_statement.json` (`model_identity`, block digests, endpoint roots), `schedule_digest` (header binding only), `token_io` and `shape` for the token stages (registered-profile checked), and `wrho_s` (forced to 17). Hard-coded: the profile registries, `BASE`, norm constants, fixture recipes. Not read as expected values: program, block `tables` private descriptors (replaced by source descriptors, 254:71-73), `plane_index` (replaced by the source index, 254:64), draw counts, H sums, host lists.

**250 port.** I read the Rust and the Python for three expressions: the norm slot (`argument_accuracy.rs:483-498` vs `d78_block_polynomials250.py:90-102`), the F bracket and rope slots (`:529`, `:605-610` vs `:106,155`), the scores slot and the B2 composition (`argument.rs:2554`, `:1250-1265` vs 250:85, `d78_block_tables249.py:101-108`, `d78_block_hosts232.py:64`). All match the source closures, not a transcription of the graph. A graph transcription would not have contained the `product6` error. The failed first attempt is retained and pinned (`d78-block-polynomial-initial250/`, with `failure.json`).

**251's 640 comparisons.** For each of 40 arguments, 16 inputs (zero vector, one vector, 14 hash-derived random vectors) are fed to the source port and to `evaluate_polynomial(argument["program"])` (the captured native IR); the two must agree (251:44-51). This tests the port against the native IR at arbitrary points, and since the slot polynomials have degree at most 5, equality at random points is strong evidence the port equals the IR as a polynomial. It supports independence of the port, and the port is the only thing 254 uses. It does not prove the IR is the native source rule; that rests on my spot reads above.

## 4. Public tables (252/253)

The 126 tables are regenerated by Python functions (`recipe_functions`, 252:36-99) and compared elementwise to the capture's arrays (`check_public_values`); they are not read from the store as the expected values. Three coherent-alteration traces, re-run by me from `trace254.py` (two words changed, digest recomputed, MLE at the actual point unchanged; CONFIRMED): stage 1 slot 4 `causal`, stage 2 slot 14 `gamma_a`, stage 2 slot 15 `rope_cos:Q`; each is refused with "source-derived public synthetic block table: <label>" and the store digest passes. The recorded 126 (60 distinct labels) all carry that message.

## 5. Controls sampled (re-run or read from named traces)

| Probe | Control | Check that refused |
|---|---|---|
| 240 | A plane offset altered | `plane_index.a_planes[0].offset value` (semantic) |
| 240 | integer to boolean id | `...a_planes[0].id type` (type check, intended) |
| 244 | reserved mask row +1, slot 18 | "private descriptors slot 18" |
| 244 | extra definition challenge | "block definition draw count" |
| 251 | coherent graph, terminal and masked-final forgery | "independent source block terminal expression" |
| 251 | changed equality family scale | "equality or private table" |
| 253 | three coherent tables (above) | derived-table check, digest passed |
| 254 | coherent terminal plus final shift | "independent source block terminal expression" (CONFIRMED) |
| 254 | late end tag | "stage end position tag"; caller transcript unchanged |
| mine | captured host coefficient altered | "source-derived block host coefficients" |
| mine | prover terminal altered | "independent source block terminal expression" |
| mine | norm cn_a 4001 | same expression check |
| mine | gate_shift 17 | "public synthetic block fixture calibration" |
| mine | zeroed table digest (contrast) | store digest (generic) |

None is refused by an earlier generic check except the contrast. The 244 "family logical id boolean" and 240 type controls are type checks by design.

## 6. Native metadata cases

The native side is a small Rust harness per probe, compiled directly with `rustc` (no cargo) from items extracted verbatim from `source-d78-188` text (`item()` in `probe_block_public253.py:29-37`, `probe_block_index240.py:149`). 226 and 245 link the existing `zkp_core` rlib. Facades bypass profile, tier and shape admission (`PublicTokenProfile`/`Tier`/`Shape`, std-only `Shape`/`Layout`); 226 returns zeros for the head fold and does not execute the define closures; 245 hand-writes structural counts and reproduces the private call schedule manually; 240 uses a constant coefficient-row-encoding adapter. All of this is stated in each report's scope (READ), and 246 corrects 245's overbroad restricted-point wording. Resource use: the large native 190 build (4.7 GiB, 195 s) and full run (9 GiB, 799 s) went through the guard (history shows `sol-r3-b3-d78-*` rows). The later harness compiles have a 45 s timeout and report peaks under 0.41 GiB, below the thresholds, and were not guarded. I ran no rustc or cargo.

## 7. Re-run (CONFIRMED)

I ran the 254 probe once from a scratch copy (it opens its outputs in Sol's directory with mode "x"): 38.0 s in my run against Sol's 38.0 s, 401 MB against 365 MB. Every field matches except `utc`, wall time, peak and the progress-log pin; terminal state is identical (`b7c34669...`), counter 4815, 33,564,688 bytes, 445 claims.

## 8. Wording versus evidence

- "Fifteen token and forty block terminal expressions are now independently evaluated from source": supported for this rung; see Finding 1 for omitted limits (specialised constants, no compact path, expression port validated against the captured IR and the live terminals).
- "Block public-table provenance is now established for this exact public synthetic fixture": supported as "equal to the Python recipe of the pinned test source"; omitted: hand transcription and the libm-float dependence (Finding 5). The caller-trust inputs listed in the same bullet are honest.
- "254 removes all 40 captured block graph objects": accurate for in-memory inputs; on-disk graphs remain.
- 255 omits that reviewer files are in its pin set (Finding 2).

## Not checked or dropped

Not checked: 229, 238, 242 internals; 193/201 PCS and mask internals; `d78_block_index239.py` and `d78_token_descriptors227.py` beyond the checks they expose; the remaining Rust slots (member 19 table host, 21/22 IO); the compact path; floating-point reproducibility of Python `math` across platforms; whether native run 190 is honest. Dropped for budget: re-running 240, 244, 245 and 226 harnesses (their recorded traces were read instead); no cargo or rustc was run.
