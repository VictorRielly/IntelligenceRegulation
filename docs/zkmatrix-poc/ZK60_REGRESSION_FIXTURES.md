# R1 — explicit, complete native regression fixtures

Scope: Python test infrastructure at base `5657a8d`. No native/prover,
transcript, acceptance-row, tensor or GPU changes. This is a configuration
repair, not a new proof or performance result.

**Integrated acceptance:** the lead's full Python/native suite passed **144
tests, zero failures and zero skips**, exit 0, in 921.316 s. All six configured
native call sites ran, including BG/BL's previously skipped smokes. Maximum
reported RSS 1,707,192 KiB, no swaps, under an 8 GiB per-process address-space
cap, two native/Rayon threads and CPU-only offline builds. See
[the combined validation](../../results/zk60_round5_validation.json). Worker
handoff statements below about pending native validation describe the earlier
isolated-worker stage, not this completed integrated run. Concurrent CL8 tests
created after discovery are not included in the 144 count.

## Cause and repair

The main checkout's `results/m125_ffn_export` contains metadata and all 36
weight tensors but lacks the 12 activation tensors. The sibling
`results/m125_ffn_export_wsl` has the complete fixed 125M export. Native
`bf_export_path` already honors `M125_EXPORT_DIR`; the test subprocesses did
not select it, while availability decorators checked inconsistent sentinels.
This matches the earlier recorded native error in
[AO §6.4](../../results/ao_l9_reencode.md#64-a-pre-existing-environment-red-found-on-the-way-out).

Three test methods invoke `freeze-check`; the BF smoke also reached the
incomplete default because its old sentinel was only `digests.txt`. These are
the four reported failure sites. Separately, the BG and BL smokes were skipped
because their old sentinel was the absent default `layer00_X.bin`. Repairing
selection enables those two smokes; a formerly green run with two skips is
not evidence that they passed. R1 has not freshly reproduced or rerun the
four native failures or the two newly enabled smokes.

[regression_fixtures.py](../../tests/regression_fixtures.py) now provides one
read-only preflight and child-environment builder:

1. An explicit `M125_EXPORT_DIR` wins. Relative paths are repository-relative;
   invalid, blank, incomplete or unsupported explicit configuration fails
   without falling back. Paths containing spaces work.
2. Without an override, try `results/m125_ffn_export`, then
   `results/m125_ffn_export_wsl`; select the first complete supported set.
   No home-directory, sibling-worktree, remote or arbitrary-model search.
3. Any `ZK_MODEL_EXPORT_DIR` setting is refused: the native loader gives it
   precedence and enters a different model-calibration path, even if it
   names the same directory.
4. Check bounded metadata, exact integer shapes `T512/d768/f2048`, ordered
   12-layer records, weight exponent -9, zero declared range violations,
   matching manifest/sidecar digest and shift entries, fixed filenames and
   all 48 tensor byte sizes. Metadata is limited to 128 KiB per file.
5. Pass the selected absolute path in a copied subprocess environment.
   Never mutate the process environment, copy or read/hash tensor contents.

This preflight checks configuration consistency, **not tensor authenticity**.
The native loader, arithmetic checks and unchanged frozen rows retain their
existing responsibilities; in particular `bf_load_layer` checks full-export
tensor hashes when `t_rows == model.t`, not for every reduced-T smoke.
It is not a malicious-directory/TOCTOU security boundary.

The four callers are [BF](../../tests/test_uagb1_pass.py),
[BG](../../tests/test_uagb1_pass_agg.py),
[BL](../../tests/test_uagb1_tblind.py), and
[native backends](../../tests/test_zkmatrix_native_backends.py).
Only fixture-dependent subprocesses use the helper. Export-based skip
decorators are removed; invalid fixtures raise `FixtureConfigurationError`,
never `SkipTest`. Existing missing-native-binary/cargo class skips are
unchanged: a complete native gate still requires prebuilt release binaries
before test discovery, otherwise those existing skips must be reported.

## Validation completed in R1

Command, from the isolated regression checkout:

```sh
python3 -m unittest discover -s tests -p test_regression_fixtures.py -v
```

Exit 0: **15 tests passed in 0.040 s**. These cover ordered fallback,
absolute/relative overrides, invalid explicit configuration, missing late
layers, wrong file types/sizes, malformed/oversized metadata, inconsistent
sidecars, higher-precedence model overrides, environment immutability, and
no tensor reads/native subprocesses. The wiring test directly calls all six
fixture-dependent test methods with mocked subprocesses and checks their
selected environment; it is not a native acceptance run.

Temporary sparse, synthetic shape placeholders support configuration tests
only; they are never submitted to a prover and are not copied model tensors.
A separate read-only call to `select_m125_fixture` against the main checkout
returned the complete WSL path both automatically and when explicitly set;
an explicit original directory was refused at `layer00_X.bin`. Exit 0.
`git diff --check` also passed. No native build, proof run or GPU run was
launched by R1.

## Newly enabled smoke inventory — not a whole-process memory bound

Both BG/BL commands execute the legacy ring aggregate path, not the hashline
private-block work. They cover two FFN layers' arithmetic with the legacy
documented table-fact/privacy gaps; they are not full transformer proofs.

| Test | Exact native arguments | Shape / behavior | Existing timeout |
|---|---|---|---|
| BF, previously attempted | `m125-pass battery smoke` | Load layers 0/1 at T16, prove layer 0 | 900 s |
| BG, previously skipped | `pass-agg prove 2 16 p0` | Two layers, T16, d768, f2048; bare groups | 1,800 s |
| BL, previously skipped | `pass-agg prove 2 16 p2` | Same shape; weight Tier-Z and T_blind | 3,600 s |

For BG/BL, source inspection of `bf_entry_shape`, `bg_entry_class`,
`bg_build_groups`, `bg_add_blind_shapes`, `bg_witness` and `bg_precommit` in
[ring_matmul.rs](../../zkmatrix-rs/src/bin/ring_matmul.rs), plus `DigitCols`
and schedule code in [eval_proof.rs](../../zkmatrix-rs/src/ring/eval_proof.rs),
gives these **component payloads**, before allocator overhead/transients:

- Six int8 weights: 9 MiB retained. Four d-wide and ten f-wide activation
  planes per layer contain 753,664 total values; even all-i64 storage is
  5.75 MiB, so these retained layer planes total at most 14.75 MiB. Loading
  and integer GEMM also create temporary full-X/weight/i64 buffers.
- P0 weight digits: `2 * 3 * (768 * 2048 / 128) * 8 = 589,824` rings,
  or **72 MiB** of flat int8 storage before row-split padding.
- Activation digits: 20,800 + 20,448 = **41,248 rings / 5,279,744 bytes**,
  using the actual layers 0/1 shifts `(9,9,6,10)` and `(7,8,7,8)` and
  native balanced-digit interval rules. Both digit groups coexist.
- P2 appends three mask shapes with 24/24/26 value rings plus one segment,
  each at 16 digit limbs: **1,200 additional rings / 153,600 bytes** before
  padding. Tier-Z changes the descent/floor allocation schedule too.
- The default streamed level-0 CRS block has at most
  `11 * 8192 * 128 * 8 = 92,274,688` coefficient bytes (88 MiB), plus boxed
  vector overhead. This bounds that block only, not simultaneous worker
  temporaries, B matrices, claim kernels, transport, descents or verifier
  reconstruction. Streaming is conditional on the schedule and environment;
  the materialized fallback can be larger.

No whole-prover RSS bound or measured RSS for these two enabled smokes has
been established here. Do not add these component figures and call the sum
a safe memory ceiling. Old full-shape RSS and historical timeout comments
are not bounds for this snapshot. Before launching, the lead must select
and enforce a host-safe memory limit and record `/usr/bin/time -v` peak RSS;
a limit failure remains visible, not a skip or acceptance.

Use the main prebuilt native binaries and its existing complete WSL fixture
(the isolated clone has neither native build outputs nor tensor files).
Native thread control is `ZK_THREADS=2`; additionally set
`RAYON_NUM_THREADS=2` and `CARGO_BUILD_JOBS=2`. Unset `ZK_MODEL_EXPORT_DIR`
and GPU-enabling `ZK_GPU`/`HL_GPU`; record any other `ZK_*` performance
overrides. Serialize heavy work with `/tmp/zk-heavy.lock`. Runs expected
over five minutes require detached logs and an exit marker.

After integration and resource approval, the intended broad gate is
`python3 -m unittest discover -s tests -v` from the main repository, with
the above CPU environment and either no `M125_EXPORT_DIR` (tests exercise
automatic WSL selection) or an explicit complete WSL path. The earlier
[foundation record](../../results/zk60_foundations_validation.json) reports
526.455 s with two skips; that is historical scheduling context, not an
R1 result or an estimate for newly enabled smokes. Full-suite native
acceptance, runtime, RSS and any remaining unrelated failures are pending
lead validation and must be recorded separately.
