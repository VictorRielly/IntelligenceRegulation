# MVP refresh validation, 2026-09-15

Baseline: `763e308b229a3478727c38388b08e1c8bc7a071c`.
Acceptance is for the experimental component and bounded diagnostics only.
The model-scale/private-block MVP and whole-proof privacy remain unfinished.

| Evidence | Result |
|---|---|
| `validation.json`, `validation.done` | 24 preceding source/tool/result hashes match; CPU example builds; 75 current endpoint tests pass; native freeze passes; full Python run: 871 tests, no failures, 60 historical fixture/log skips |
| `fresh_io_tests.json`, `fresh_io_tests.log` | Existing IO tests explicitly pointed at retained round-22 captures: 36 tests, no failures, three unavailable legacy-capture cases skipped |
| `demo_validation.json`, `demo_validation.done`, `demo_manifest.json` | Real default build/prove/verify flow: nine process stages including six rejection controls; 5,029,244-byte receipt; existing-output refusal and all artifact hashes checked |
| `integration_stages.json`, `final_demo_tests.log` | Final integrated demo tests: 37 pass |
| `final_security_tests.log`, `security_probe.json` | 16 tests pass; four retained captures; eight fixed-challenge IO zero-data preimages; 40 corrupted observations refused; eight conditional endpoint preimages; four shared-mask functional rank checks |

The initial detached validation attempt stopped before any stage because this
host's Python 3.10 lacks `hashlib.file_digest`. The runner was corrected to
stream hashes; `runner.log` and `setup_failure.done` retain that failed setup
attempt. `validation.done` records the completed rerun. The first sandboxed
background launch was terminated by its sandbox; successful long runs used
detached processes outside that sandbox and the shared `/tmp/zk-heavy.lock`.

`demo_unit_tests.log` is an earlier 35-test candidate run. The final 37-test
run includes the completed Opus delivery and Codex review corrections. The
full suite started before the new files were integrated; the final focused
logs separately cover all 53 new tests.

The randomized real receipt and control variants are retained locally in
`../zk60_mvp_20260915_demo/` (gitignored). `<source>` and `<output>` in the saved
demo manifest mean the source checkout and that artifact directory. The
synthetic fixture values are public; these artifacts establish tested behavior,
not privacy for application secrets or throughput at model scale.

The security probe deliberately leaves caller-fixed endpoint simulation and
adaptive/joint privacy open. Read
[Codex's disposition](../../docs/zkmatrix-poc/ZK60_MVP_REVIEW.md) before using
any delegated security recommendation. `fable_delivery/` preserves the original
proposal unchanged; its broader security conclusions were not accepted.
`final_summary.json` binds the final source files and all completed run evidence.
