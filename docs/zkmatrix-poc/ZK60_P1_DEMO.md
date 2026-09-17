# ZK60 P1 FFN component demo — one command, CPU only

`scripts/zk60_p1_demo.py` runs the whole P1 bound-FFN loop from a clean
checkout: register the public weights, prove one FFN with private input,
output and intermediate values, verify the saved receipt bytes in a separate
process, and check that the verifier refuses six wrong inputs. It writes every
command, exit code, artifact hash and timing into one JSON manifest.

**This is a component demo, not a block and not an MVP.** Whole-proof zero
knowledge for the P1 private set is unresolved (see
[ZK60_PRIVACY_REQUIREMENTS.md](ZK60_PRIVACY_REQUIREMENTS.md) and
[ZK60_ROUND25.md](ZK60_ROUND25.md)); the tensors are a small public synthetic
fixture, not a model; one FFN is not a transformer block. A passing run means
"this component proved and verified end to end, and the verifier rejected the
listed wrong inputs" — nothing about privacy being established. The manifest
says so in `status_claims`, and the script never rewrites those flags.

No model download and no hand-built fixture are needed: the fixture is
`public_synthetic_fixture()` inside the crate.

## Run it

```
python3 scripts/zk60_p1_demo.py --output results/zk60_p1_demo_<date>
```

Proving is a heavy job. On the shared box, wrap the command in the project's
heavy lock and detach it (`CLAUDE.md`, the no-hangup protocol); the script
deliberately does **not** take the lock itself, so it composes with whatever
queueing the caller already uses:

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock python3 scripts/zk60_p1_demo.py \
  --output results/zk60_p1_demo_<date> >> <log> 2>&1; echo $? > <log-stem>.done' \
  >/dev/null 2>&1 &
```

Exit status is 0 only if every stage did exactly what was expected. Anything
else — a crash, a timeout, malformed output, a rejection that was accepted —
exits 1 and leaves the reason in `<output>/manifest.json` under `failure`.

### Options

| Option | Meaning |
|---|---|
| `--output DIR` | required; must not exist. Artifacts and `manifest.json` land here. An existing file or directory is never written to or deleted. |
| `--binary PATH` | reuse an already built CPU `zk60_bound_ffn` example instead of building. |
| `--source DIR` | source checkout root; defaults to the repository containing the script, so worktrees and moved checkouts work with no edit. |
| `--cargo PATH` | cargo to build with (default `$CARGO`, else `cargo`); pass the rustup toolchain by absolute path if `cargo` is not on `PATH`. |
| `--threads N` | `RAYON_NUM_THREADS` and `CARGO_BUILD_JOBS` for every child, from 1 to 16 (default 2). |
| `--timeout S`, `--build-timeout S` | positive finite per-process limits (default 1800 s and 3600 s). |

### Prerequisites

- A Rust toolchain with `cargo`, and `hashline/Cargo.lock` present: the build
  is `cargo build --locked --release --manifest-path <source>/hashline/Cargo.toml
  --example zk60_bound_ffn`, default features, CPU only. `--locked` means a
  lockfile-changing dependency resolution fails the run instead of drifting.
- The example path comes from cargo's own JSON messages, so a redirected
  `CARGO_TARGET_DIR` is fine.
- `hashline/examples/zk60_bound_ffn.rs` is used **unchanged**; the demo hashes
  it into the manifest. No production Rust is touched.
- Python 3 standard library only.

## What the run does

1. **`prepare`** — public-weight registration, before any proving. The manifest
   records its `public_weight_root`; the run fails if it reports
   `proving_executed: true` or a value that is not a digest.
2. **Caller context** — 32 bytes of fresh OS randomness per run (`os.urandom`),
   held by this script, not read back from any artifact.
3. **`prove p1 <context> p1.expected p1.receipt`** — the trusted fixture caller
   commits both endpoints and saves the public endpoint policy *before* FFN
   proving. The script then checks the saved policy field by field against
   values it already holds: the `HFFNEXP1` magic, its own context, the
   `(-3, 0)` scales, and the roots the prover reported.
4. **`verify p1 <registered root> <context> p1.expected p1.receipt`** — a fresh
   process that reads only the saved bytes. The expected trust policy is *not*
   derived from the candidate receipt: the weight root comes from step 1, the
   context from step 2, and the endpoint roots from the policy file written in
   step 3 and already validated against the caller's own context and scales.
5. **Rejection controls** — each must exit 1, print nothing on stdout and
   explain itself on stderr:

   | Control | What is wrong |
   |---|---|
   | `reject_wrong_context` | a different fresh 32-byte request context |
   | `reject_wrong_public_weight` | an all-zero public weight root |
   | `reject_wrong_endpoint_policy` | one bit flipped in the policy's input root |
   | `reject_tampered_receipt` | last receipt byte flipped |
   | `reject_truncated_receipt` | receipt minus its last byte |
   | `reject_trailing_receipt` | receipt plus one trailing byte |

   An acceptance here fails the run with `ACCEPTED a case it must reject`.
6. **Preservation check** — the original receipt and policy bytes must be
   unchanged after the controls.

## Environment handling

Every child process runs with a sanitized environment: all `HL_*` variables are
removed (that covers `HL_GPU` and any fixture-randomness switch), and
`RAYON_NUM_THREADS` and `CARGO_BUILD_JOBS` are set. The removed names are listed in the manifest, so an
injected switch shows up as evidence rather than silently changing a run. The
demo only ever invokes `p1`; no `p3` path, no legacy privacy flag, no GPU
feature. The example itself also refuses to run under a GPU build.

Hidden values are never printed. Only public handles appear in the manifest:
commitment roots, the request context, the public weight root, artifact hashes.

## The manifest

`<output>/manifest.json`, rewritten after every stage so a killed or failed run
still explains itself:

- `status` (`passed` / `failed`) and, on failure, `failure.reason` plus the step.
- `build`: exact command, flags, exit code, seconds; `binary`: size and SHA-256;
  `example_source`: SHA-256 of the unchanged Rust example.
- `steps`: for each process, the command, working directory, expected and actual
  exit code, seconds, stderr, and the parsed result JSON for accepted runs.
- `artifacts`: size and SHA-256 of the receipt, the endpoint policy and each
  control variant.
- `coverage.covers` / `coverage.does_not_cover` and `status_claims`
  (`full_private_block: false`, `mvp: false`,
  `whole_proof_zero_knowledge_established: false`).
- `environment`, `public_weight_root`, `caller_context`, `verification`.

Paths are written as `<source>/...` and `<output>/...` tokens, so manifests from
different checkouts compare cleanly. `timing_note` states what the seconds are:
diagnostics on a shared box. **They are not a benchmark** — this project's
timing rules require a quiesced box, and the demo makes no speed claim.

## Relationship to `scripts/zk60_bound_ffn_process_check.py`

That script is the broader per-mode control battery (p1 and p3, ~30 cases) and
requires a pre-built binary. This one is the single-command P1 entry point:
it builds, uses fresh randomness, keeps a smaller control set and produces the
portable manifest. Neither replaces the other, and neither establishes privacy.

## Status

Validated on 2026-09-15: the default build-and-run command produced a
**5,029,244-byte receipt**, verified it in a separate process and rejected all
six controls. Reusing the output directory was refused and the artifact hashes
remained unchanged. The 37 orchestration/failure tests also pass.

Exact commands, logs, hashes and the portable demo manifest are retained in
`results/zk60_mvp_20260915_evidence/`. The randomized receipts themselves remain
local in the gitignored `results/zk60_mvp_20260915_demo/` directory. See the
[integration review](ZK60_MVP_REVIEW.md) for corrections and acceptance limits.
