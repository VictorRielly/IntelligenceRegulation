# ZK60 zkVM runner (`scripts/zk60_zkvm_demo.py`)

A standard-library Python runner for two separately versioned zkVM
experiments. You choose one with `--profile`:

| Profile | Crates | Binaries | Model | Owner input | Private output | Policy tag |
|---|---|---|---|---|---|---|
| `block` (default) | [`zkvm-block/`](../../zkvm-block/README.md) | `zk60-block-{host,wrap}` | 6,184 B `Z60MDL01` | 1,024 B (512 LE i16) | `output.i16` | `zk60-r0-block-v1` |
| `token` | [`zkvm-model/`](../../zkvm-model/README.md) | `zk60-token-{host,wrap}` | 13,928 B `Z60TOK01` | 128 B (32 LE u32 IDs, `0..31`) | `output.u32` | `zk60-r0-token-v1` |

Both profiles use the same 144-byte policy (journal) layout: a 16-byte tag,
then context, model, input and output (32 bytes each). The runner checks the
policy tag. It never infers a profile from a policy or a receipt. A run with
no `--profile` is a block run, exactly as before.

**What this is not.** The block profile is one small block, reexecuted in the
RISC Zero zkVM. The token profile is exactly
`synthetic-T32-V32-two-block-greedy-token`: two blocks, followed by one greedy
next token over a vocabulary of 32. It uses the **synthetic, untrained**
fixture model, whose tables are not a registered calibration. The token stays
private (`output.u32`) and is never published. Neither profile is the
model-scale MVP, a trained model or an accepted D7 result. Neither produces
benchmark numbers. The manifest's `not_claimed` block records this on every
run. A child that prints `"mvp_complete": true` fails its stage. Stage seconds are kept only in private
bookkeeping, as diagnostics for a shared machine. Every acceptance flag starts
`false` and becomes `true` only after its real stage succeeds. The unit tests
(`tests/test_zk60_zkvm_demo.py`) run **mock** binaries that generate no proof.
A passing test means the orchestration and filesystem rules work. It is not
evidence that any receipt is sound.

## Prerequisites (explicit, never fetched or built here)

| Argument | What |
|---|---|
| `--profile` | `block` (default) or `token` |
| `--expected-image-id` | optional approved guest image id (exactly 64 lowercase hex). If you give it, the run stops before `prepare` unless both binaries report exactly this id |
| `--model` | `MODEL_BIN` for the profile: block 6,184 bytes `Z60MDL01`, token 13,928 bytes `Z60TOK01` (formats in each crate README) |
| `--host` | prebuilt `zk60-block-host` or `zk60-token-host` (`<crate>/target/release/`) |
| `--wrap` | prebuilt `zk60-block-wrap` or `zk60-token-wrap` |
| `--r0vm` | local `r0vm` server. Its `--version` output must contain `--r0vm-version` (default `3.0.6`) |
| `--native-tools` | directory holding the extracted `prover`, `stark_verify`, `stark_verify.dat`, `stark_verify.cs` and `stark_verify_final.pk.dmp` |
| `--out` | **new** output root. The runner creates it with mode 0700 |
| `--public-dir` | optional **new** public directory outside `--out` (default `OUT/public`) |
| `--input` | optional owner input of the profile's exact size (block 1,024 bytes, token 128 bytes). Switches to `prepare-input` |
| `--native-hashes` | optional artifact record from `scripts/zk60_groth16_tools.py`, or a JSON list of `{file, bytes, sha256}`. It must cover all five tool files; each is compared under the lock |
| `--threads` | sets `RAYON_NUM_THREADS`, `OMP_NUM_THREADS` and `GOMAXPROCS` (default 2) |
| `--{execute,prove,wrap,short}-timeout` | per-stage bounds in seconds. Defaults: 3600, 14400, 14400, 600; `prepare` is 600 |

The runner does not compile anything or download the native tools, which is
handled separately. It never selects a remote prover. It removes every `BONSAI_*`,
`RISC0_*`, `HL_*` and `RUST_LOG*` variable from the child environment; only
the removed *names* are recorded, privately. This scrubbing is required by
the token CLIs, which refuse to start if `RISC0_DEV_MODE`, `RISC0_PROVER` or
any `BONSAI_*` is set. The binaries use the explicit local `r0vm` path, and
they force dev mode off themselves.

## Use

Before a heavy run, check that no other proof is running (`/tmp/*.done`
markers, the loop record). The runner queues on `/tmp/zk-heavy.lock` whatever
the answer. Use absolute paths throughout.

```
python3 scripts/zk60_zkvm_demo.py launch \
  --model /abs/model.bin \
  --host /abs/zkvm-block/target/release/zk60-block-host \
  --wrap /abs/zkvm-block/target/release/zk60-block-wrap \
  --r0vm /home/victor/.cargo/bin/r0vm \
  --native-tools /abs/groth16-native \
  --out /tmp/zk60-zkvm-demo-RUNID
python3 scripts/zk60_zkvm_demo.py status /tmp/zk60-zkvm-demo-RUNID
python3 scripts/zk60_zkvm_demo.py verify --profile block \
  --expected-image-id TRUSTED_64_HEX --wrap /abs/zk60-block-wrap \
  --policy /trusted/policy.bin --receipt /tmp/zk60-zkvm-demo-RUNID/public/receipt.bin

# token profile
python3 scripts/zk60_zkvm_demo.py launch --profile token \
  --expected-image-id TRUSTED_64_HEX \
  --model /abs/token-model.bin \
  --host /abs/zkvm-model/target/release/zk60-token-host \
  --wrap /abs/zkvm-model/target/release/zk60-token-wrap \
  --r0vm /home/victor/.cargo/bin/r0vm \
  --native-tools /abs/groth16-native \
  --out /tmp/zk60-zkvm-token-RUNID
python3 scripts/zk60_zkvm_demo.py verify --profile token \
  --expected-image-id TRUSTED_64_HEX --wrap /abs/zk60-token-wrap \
  --policy /trusted/policy.bin --receipt /tmp/zk60-zkvm-token-RUNID/public/receipt.bin
```

- `launch` checks every prerequisite and destination. It creates the output
  root, starts a detached worker (`start_new_session`, which survives the
  session ending), prints `{launched, pid, status, done}` and returns.
  Configuration errors are reported at once and create nothing.
- `run` takes the same arguments and runs in the foreground. Use it for short
  checks only; heavy runs should use `launch`.
- `status OUT` prints the state, the current stage, the error, the flags and
  the exit code. It exits 0 on success, 1 on failure and 2 while the run is not
  finished. `runner_alive: false` without a marker means the worker was
  hard-killed (SIGKILL/OOM); the run then reports `died-without-marker`.
- `verify` is the independent check. `--profile` and `--expected-image-id`
  are both **required**. There is no default, and nothing is inferred from the
  candidate files. The check runs in this order and stops at the first
  refusal:
  1. The policy must be 144 bytes and start with the profile's tag.
  2. `WRAP image-id` runs in a fresh process, and its output must equal
     `--expected-image-id` exactly.
  3. `WRAP verify` runs in another fresh process, with a bounded timeout. The
     token profile appends the same expected id as the final argument, which
     the token verifier requires. The block verifier takes no image argument;
     for it, the binding rests on step 2, meaning the block binary reports
     the image its verifier was compiled against.

  The check accepts only exit 0 plus one JSON line with `verified: true` and
  `kind: "groth16"`. The printed result names the profile and the expected
  image id. **Get `policy.bin` and the image id through an independent
  trusted channel.** The policy or image id that sits next to a candidate
  receipt, or that appears in its `outcome.json`, does not authorize anything.

## Stages (fail closed, in order)

The worker first checks the prerequisites again. It then waits on
`flock /tmp/zk-heavy.lock` (state `waiting-for-heavy-lock`) and holds the lock
for every stage below. It releases the lock when it exits; the kernel releases
it if the worker dies.

1. `native-hashes` (only with `--native-hashes`).
2. `r0vm-version`, then `host-image-id` and `wrap-image-id`. The runner
   records both reported ids privately in `status.json`. They must be equal
   (64 lowercase hex characters). If `--expected-image-id` was given, they
   must also equal it. Otherwise the runner stops before `prepare` creates the
   public or private directory. The agreed id is the only one passed to later
   token verify calls. It is never read from a receipt.
3. `prepare` (or `prepare-input`). The host creates `PUBLIC/{model.bin,policy.bin}`
   and `OUT/private/{request.bin,<private output>}` (`output.i16` for block,
   `output.u32` for token), with the private directory at 0700. The runner
   then confirms these conditions:
   - the private directory is 0700, holds exactly those two files, and its
     files are set to 0600;
   - the public directory holds exactly those two files;
   - the public `model.bin` is byte-identical to `--model`;
   - `policy.bin` is 144 bytes and starts with the selected profile's tag.
4. `execute`: the guest runs, and the journal must match the policy. It must
   write no receipt.
5. `prove`: the succinct receipt goes to **private** `OUT/private/inner.bin`,
   which the runner sets to 0600. `inner-verify` then checks it with the host
   verifier in a fresh process. The token host also receives the agreed image
   id.
6. `groth16-wrap`: local native Groth16 goes to **public** `PUBLIC/receipt.bin`.
   The work directory is `OUT/private/wrap-work` (0700; witness and native
   logs). The public directory is audited before (two files) and after (three
   files).
7. `groth16-verify`: the wrap binary's `verify` runs in a fresh process, with
   the agreed image id for token. It must report `verified: true` and
   `kind: "groth16"` on the same JSON line.
8. Rejection controls. Each one must exit exactly 1, print an error, and print
   no `"verified":true` line. The control files live in `OUT/private/controls`
   (0600).
   - `reject-wrong-{profile,context,model,input,output}`: one bit flipped in
     the trusted policy at bytes 0, 16, 48, 80 and 112.
   - `reject-inner-receipt-kind`: the public Groth16 verifier is given the
     private succinct `inner.bin`, and must refuse it for its receipt kind.
   - `reject-wrong-image-id` (token only): the valid policy and receipt, with
     the last hex digit of the image id changed. It sets
     `wrong_image_id_rejected`. The block verifier takes no image argument,
     so the block profile has no such control and no such flag.
   - `reject-{truncated,trailing-byte,empty,flipped-first-byte,flipped-middle-byte,flipped-last-byte}`:
     malformed or tampered copies of `receipt.bin`.
9. `public-audit`: the public directory holds exactly `model.bin`,
   `policy.bin` and `receipt.bin`, all regular files. The runner then writes
   `outcome.json` and audits again.

If any stage exits unexpectedly, times out, or breaks an audit, the run stops.
The same happens if a control is *accepted*, if any child prints
`"mvp_complete": true`, or if the worker receives SIGTERM/SIGHUP/SIGINT. Later stages never run, and their flags stay `false`.

## Process and filesystem rules

- Each child runs in its own session/process group. Its stdout and stderr go
  to a new 0600 log in `OUT/logs/` (opened `O_EXCL|O_NOFOLLOW`), never to the
  runner's own output. The logs are kept after the run, for private diagnosis
  only.
- When a stage times out or the runner is interrupted, the child's whole
  process group gets SIGTERM, then SIGKILL after a grace period. The runner
  reaps the leader only after the SIGKILL, so the group id cannot be reused.
  This also kills an `r0vm` or native prover started by the child. After a
  normal exit, any processes left in the group are killed too.
- Destinations must not exist: not even as a dangling symlink. Their parent
  must be a real directory reached without symlinks. The public directory must
  be disjoint from the output root, `private/` and `logs/`. The runner creates
  every file with `O_CREAT|O_EXCL|O_NOFOLLOW`, and the Rust binaries refuse
  existing outputs too, so nothing is overwritten.
- `OUT/run.done` holds the exit code: `0` means accepted, `1` means anything
  else. The runner writes it in a `finally` block, fsyncs it and fsyncs its
  directory. It is missing only when the worker is hard-killed.

## Output layout

```
OUT/                     0700  runner-created; do not publish
  config.json            0600  resolved prerequisite paths
  status.json            0600  state, stages (commands, exit codes, seconds, log paths), error
  run.done               0600  exit code
  logs/                  0700  NN-<stage>.log (0600), runner.log for detached runs
  private/               0700  request.bin, output.i16|output.u32, inner.bin, controls/, wrap-work/
  public/                      model.bin, policy.bin, receipt.bin, outcome.json
```

By default `public/` sits inside the 0700 root, so its files are readable only
by the owner until you copy them out. After a failed run the public directory
may hold `model.bin`, `policy.bin`, an unaccepted `receipt.bin` and an
`outcome.json` that says `failed`. Publish its contents only when
`outcome == "accepted"`.

## `outcome.json` (public manifest)

The manifest contains only public facts. Everything else stays in the private
`status.json`: paths, salts, inputs, outputs, logs, timings, error text,
environment details and whether an owner input was used.

| Field | Meaning |
|---|---|
| `schema` | `2` (the profile fields were added) |
| `profile`, `policy_profile_tag` | the selected profile and its policy tag |
| `experiment`, `coverage` | fixed per profile: `zk60-zkvm-complete-block` (one T32/d16/f16 block) or `zk60-zkvm-token-model` (`synthetic-T32-V32-two-block-greedy-token`, untrained, token private) |
| `outcome` | `accepted` only if every stage passed and every flag is true; otherwise `failed` |
| `failed_stage` | the stage name where the run stopped, or `null` |
| `receipt_kind` | `groth16` only after the fresh-process public verifier accepts, otherwise `null` |
| `guest_image_id` | the image id both binaries report, which also equals the pin if one was given (`null` if the run stopped earlier) |
| `image_ids_reported` | what the host and the wrap each reported (`malformed` for anything that is not 64 lowercase hex) |
| `expected_image_id_pinned` | whether the run was given `--expected-image-id` |
| `artifacts` | `{bytes, sha256}` for each of `model.bin`, `policy.bin` and `receipt.bin` that is present |
| `acceptance.prepared` | prepare succeeded and the post-prepare checks held |
| `acceptance.execution_matches_policy` | the `execute` stage succeeded |
| `acceptance.inner_receipt_verified_privately` | `prove` plus the fresh-process host verification of the private inner receipt |
| `acceptance.groth16_wrapped` | the wrap succeeded and the three-file public audit held |
| `acceptance.groth16_verified_fresh_process` | `zk60-block-wrap verify` accepted the receipt |
| `acceptance.wrong_policy_rejected` | all five one-bit policy changes were refused |
| `acceptance.inner_receipt_refused_by_public_verifier` | the receipt-kind control was refused |
| `acceptance.wrong_image_id_rejected` | token only: the wrong-image control was refused |
| `acceptance.malformed_receipts_rejected` | all six malformed or tampered receipts were refused |
| `acceptance.public_directory_audited` | the final audit found exactly the three artifacts |
| `acceptance.all_passed` | the conjunction of all the flags above, and no stage failed |
| `not_claimed` | always `false`: `model_mvp_complete`, `model_scale_mvp`, `trained_model`, `d7_accepted`, `benchmark`, plus `token_generation` (block) or `token_disclosed` (token) |
| `policy_note` | reminds the verifier to obtain `policy.bin` and the image id independently |

An accepted outcome means this runner watched the listed local stages
succeed. For the privacy and soundness arguments, and their premises, see the
crate READMEs and `ZK60_ZKVM_SOURCE_REVIEW.md`. A manifest says nothing
beyond those arguments. Its `guest_image_id` is what the binaries *reported*,
not an approval. A third party should rerun `verify` with its own trusted
image id rather than trust the manifest.

## Tests

```
python3 -m unittest discover -s tests -p test_zk60_zkvm_demo.py
```

The tests use no network and generate no proof. The mock host, wrap and r0vm
are Python/sh scripts labelled MOCK. They imitate each profile's argument
contract: the token verifiers take a trailing image id, and the token CLIs
refuse `RISC0_DEV_MODE`, `RISC0_PROVER` and `BONSAI_*`. The tests cover:

- the mock pipeline's public file set, modes and the absence of private
  content in the manifest, for both profiles;
- that every stage runs under the lock;
- the complete list of controls, including the receipt-kind control using
  `inner.bin`, and the token wrong-image control;
- fail-closed stops, with the correct flags, on:
  - a prove failure;
  - a lax verifier, and a token verifier that ignores its image argument;
  - a verifier reporting the wrong kind;
  - a child claiming `mvp_complete`;
  - a stray public file;
  - a host/wrap image-id mismatch and an `--expected-image-id` mismatch;
  - a wrong-profile policy tag after prepare;
  - a wrong-profile model or owner input;
- that token binaries never see the refused prover variables;
- standalone `verify`:
  - `--profile` and `--expected-image-id` are required, and a malformed id
    is refused;
  - a wrong image id is refused before `verify` runs;
  - a candidate of the other profile is refused on its policy tag, with no
    binary run;
- timeout and SIGTERM cleanup of the process group, including a child that
  ignores TERM;
- overwrite, symlink and nested-destination refusals;
- detached launch, the lock queue and `status`.
