# Gate round 26: independent check of the three wiring readings

Reader: Claude (Opus 5.5), an agent that did not write the round-26 change or its readings. Date: 2026-11-02.
This is a READ-ONLY source review. **It is not a privacy acceptance**, and it does not reopen P1. No build, test or
proof was run. I read the code first. I opened `READINGS_R26_WIRING.{json,md}` only afterwards, to compare.

## The short answer

| pin | digest checked | scope | verdict |
|---|---|---|---|
| `hashline/src/private_block/run_capture.rs` | `cbb78dc0…` → `10b6d3be…` | the diff (6 hunks) and the two manifest writers | **SAFE**. It has one Medium limit on what `proved_on_gpu` means for a bundle whose proof came from another process (W-1). |
| `hashline/src/gpu/metal.rs` | `a96882bc…` | CPU path (`proved_on_gpu: false`) | **SAFE for receipt bytes.** It does write one constant string into a CPU-made bundle's `README.md` (W-3). |
| `hashline/src/gpu/metal_kernels.metal` | `be968236…` | CPU path | **SAFE.** With `HL_GPU` unset, no byte. |

No finding is High. Nothing private, and nothing derived from private data, enters a bundle through this change.
For the four fresh D55 bundles, `proved_on_gpu: false` is faithful. Their proofs ran in the writing process, with
`HL_GPU` unset, under `--exact --test-threads=1`.

## How I checked the digests

I hashed `git show <rev>:<path>` with SHA-256 for each revision. HEAD is `perf/zk-batch-optimizations` at `9432e88a`;
my worktree was fast-forwarded to it, and the files on disk hash the same.

| file | `23199feb^` | `23199feb` | HEAD |
|---|---|---|---|
| `run_capture.rs` | `cbb78dc04ac5ca62e56318ae6b2e844666ef3016e03a774e81d7e3d6dc569135` (222,202 B) | `10b6d3be860c73cd257e4b6b040b0351f10b993d8b1d1fdb5775057b71ef21c7` (223,234 B) | `10b6d3be…` |
| `gpu/metal.rs` | `a96882bcc6716deedd37f56ba3846724a015c232f84a6d6e26f08667593a121d` (92,982 B) | the same | the same |
| `gpu/metal_kernels.metal` | `be9682364115ea8d94a2db6bfd68cc2ec6585c92448b1548813ef82a565b3b88` (39,117 B) | the same | the same |

All three match the digests I was asked to check. The five retained manifests in
`results/zk60_d60_20261102/privacy_gate_r26/bundle_manifests/` pin these same three digests, with 75 pins each.

My trace also relies on supporting files. I read them at the digests the fresh bundles pin:

* `gpu/mod.rs` `d7812f7d…`
* `private_block/argument.rs` `86c9941d…`
* `zkp-core/src/pcs.rs` `856929b3…`
* `src/pcs.rs` `8b14096b…`
* `private_block/trained_block.rs` `9909e883…`
* `private_block/metal_slot.rs` `5ced3891…`

Each equals the file's entry in `bundle_manifests/d55-r13_rung_h24-s0/manifest.json`.

All paths below are under `ops/zkp-mvp/gpu-metal/hashline/`, except `zkp-core/...`, which is under
`ops/zkp-mvp/gpu-metal/`.

---

## Pin 1: `src/private_block/run_capture.rs`, `cbb78dc0` → `10b6d3be`

### What I read

* The diff from `git diff 23199feb^ 23199feb -- …/run_capture.rs`: 6 hunks, +20 / −5.
* The two manifest writers in full: `write_fork_bundle` (:4421-4481) and `write_bundle` (:4483-4607).
* How pins are made: `source_files` / `source_pins` (:4613-4627) and `classify_source_pins` (:3655-3674).
* The allow-list `ALLOWED_KEYS` (:4046 onward, with the new key at :4279-4280).
* The module gate: `#[cfg(test)] mod run_capture;` at `src/private_block.rs:266-267`.
* Every caller of both writers. The relevant ones are in `run_fork_tests.rs`, `token_io/capture_tests.rs`,
  `token_io/classify_capture_tests.rs`, `token_io/gate19_capture_tests.rs` and `w16_privacy_gate_tests.rs`.

### Hunk by hunk

1. **:170, the array length `29 → 31`.** A type. The compiler checks it.
2. **:219-226, two pins added to the end of `SHARED_SOURCE_FILES`: `src/gpu/metal.rs` and
   `src/gpu/metal_kernels.metal`.**
   * A pin is a file name plus the SHA-256 of that public source file. `source_pins` reads the file from
     `CARGO_MANIFEST_DIR` when the bundle is written (:4618-4626).
   * Nothing from it is absorbed into a transcript, frame or statement.
   * `source_files` is OWN then SHARED (:4613-4614), so every earlier pin keeps its position. The classifier's five
     pins, which come after SHARED (:3666-3673), move back by two places (W-8, Info).
3. **:315-323, a comment.** It corrects the M26 note about `slot_ir.rs` / `metal_slot.rs`. Text only.
4. **:4279-4280, `"proved_on_gpu"` added to `ALLOWED_KEYS`.**
   * No `run.json`, stage, tail or array writer emits it. Those writers are unchanged.
   * The allow-list is one flat list for every file (W-7, Info).
5. **:4467-4469, `write_fork_bundle` writes `"proved_on_gpu":<bool>` between `writer` and `source_pins`.**
   * The value is `crate::gpu::enabled()`, read when the manifest is written.
   * Rust's `{}` of a `bool` prints the JSON words `true` / `false`.
6. **:4587, `write_bundle` writes the same field after `source_commit`, with the same value.**

### Can a bundle now carry anything private?

No. The diff adds only three things to what a bundle carries:

* two `(file, sha256)` pairs of public source files;
* one boolean.

The boolean is a function of the process environment: whether `HL_GPU` is `"1"` and whether the Metal device
initialised (`metal.rs:96-109`). It is not a function of any witness, input, output, activation, pad, mask, salt or
random draw. It also tells a reader nothing the bundle did not already say:

* The D60 writer test's README note has always included `gpu::label()` (`run_fork_tests.rs:1175-1178`). This diff did
  not add that.
* All four retained READMEs say `proved and verified on this path: gpu: off (built with gpu-metal; HL_GPU unset)`.

The diff does not touch `run.json`, the stage files, the tail, `arrays.bin`, the receipt frames or the README text.

### Does it change what the gate sees in a way that would hide a leak?

No.

* The gate sees more coverage: two more pins.
* The gate gets a handle to refuse bundles: GPU-made bundles and bundles with no record are refused
  (`staging_v25/scripts/zk60_native_rg_r26readings.py:291-320`, applied in `zk60_native_rg_w16.py:581-586`).
* The Python readers I found index pins by file name, not by position (`zk60_native_rg_classpins.py:404, :448`;
  `zk60_native_rg_block.py:484`). The classifier pins' shift therefore misleads nothing.

The only way this change could hide something is if `proved_on_gpu: false` were written for a proof that partly ran
on the device. Then the CPU-path readings below would admit device code nobody has read. That is the next question.

### Does `proved_on_gpu` faithfully record how the proof was made?

**The registered D55 fork writer (`write_fork_bundle`), which made the four fresh bundles: yes, under the recorded
procedure.**

* The proof is made in the writing process:
  * `prove_run_with_forks` at `run_fork_tests.rs:1113` (rung) and `:1169` (trained base);
  * the recorded verify at `:991-1003`;
  * the write at `:1179`.
* The D55 CLI fails closed for D55 runs (`run_fork_tests.rs:1417`), so no out-of-process D55 prover exists.
* The four bundles were written with these settings (`privacy_gate_r26/README.md:143-150, :352`):
  * `HL_GPU` unset;
  * a gpu-metal test build;
  * `--ignored --exact --nocapture --test-threads=1`, naming the one test.
* With that procedure, `enabled()` returns false at every call in the process (`metal.rs:97-98`). Every device entry
  is then off (see pin 2).

**The generic writer (`write_bundle`): not by construction (W-1, Medium).** Its value is `enabled()` in the
*capture-test process*. For several existing capture tests that process did not make the proof:

* `token_io/capture_tests.rs:640-668`: with `HL_PB_CLI_BIN` set, `prove` runs as a child process of a named binary.
  The bundle is then written at `:723`.
* `token_io/classify_capture_tests.rs:689-705` and `:772-800` *always* prove through a named `zk60_classify` binary.
  They write at `:735` and `:840`.
* `token_io/gate19_capture_tests.rs:387-439` does the same, for the real-content classifier run.

The child inherits `HL_GPU`, but it may be a different build. Here is the bad case:

* the child is a gpu-metal binary, run with `HL_GPU=1`;
* the capture test is a no-feature build.

The result is a receipt made partly on Metal under a manifest that says `proved_on_gpu: false`. The opposite pairing
(a gpu-metal capture test with `HL_GPU=1`, a CPU child) says `true` for a CPU proof. That error is harmless, because
the gate refuses it.

**Both writers: the value is read when the manifest is written, not latched at proof time (W-2, Low).** A wrong value
needs another test in the same process to flip `HL_GPU` between the proof and the write. See pin 2.

**The other direction is harmless.** `HL_GPU=1` with every device call declined still says `true`
(`gpu/mod.rs:60-66`; no panic unless `HL_GPU_REQUIRED=1`). The gate refuses that bundle.

### Verdict

**SAFE at the scope of this diff.**

* No hunk lets a bundle carry anything private.
* No hunk weakens what the gate sees.
* `proved_on_gpu` is faithful for the four registered D55 bundles.

It is not a guaranteed record for `write_bundle` bundles whose proof came from a CLI child process (W-1). Today it
cannot be wrong without a concurrent in-process toggle (W-2).

### Where I differ from the self-reading

* The self-reading (hunk 5, applied to hunk 6 by "the same argument") says the value "is read in the proving process
  at write time: both writers run in-process". The writers do run in-process. The **prover** does not, for the
  CLI-path capture tests above.
* Its note "A future out-of-process writer … would have to carry the value from the proof (none exists at 23199feb)"
  misses that an out-of-process **prover** already exists at 23199feb.
* This does not affect round 26. The backend rule (`gpu_backend`) and the `false`-only admission of the CPU-path
  readings (`reading_for`, `zk60_native_rg_r26readings.py:269-277`) are called from one place: the shared
  `classify_pins` in `zk60_native_rg_w16.py:563-600`.
  * The W16 gate uses it at `zk60_native_rg_w16.py:696`, and the D55 gate at `zk60_native_rg_d55.py:774` and `:897`.
  * Both gates read bundles proved in the writing process: the W16 writer proves through `prove_and_capture`
    (`w16_privacy_gate_tests.rs:228-255`, `run::prove_run` in-process), and the D55 fork writer as above.
  * D55 has no CLI path.
  * The token and classifier gates do not call `gpu_backend`.
  * It would matter the day the backend rule is applied to token or classifier bundles.
* Its claim "no test changes HL_GPU between the proof and the write" is true of each single test. It is not true of
  tests that share a process (W-2).

---

## Pin 2: `src/gpu/metal.rs` at `a96882bc`, CPU-path scope

The question: in a bundle whose manifest says `proved_on_gpu: false`, could this file have influenced any receipt
byte, or any byte written into the bundle?

### How `crate::gpu::enabled()` is computed

* **Features** (`Cargo.toml:15-30`). There is no `default` feature list, so a plain build has neither `gpu-cuda` nor
  `gpu-metal`.
  * The Metal module is compiled only under `all(feature = "gpu-metal", not(feature = "gpu-cuda"))`
    (`gpu/mod.rs:25-28`), so CUDA wins if both are on.
  * Without either feature, `enabled()` is the constant `false` (`gpu/mod.rs:829-842`). `metal.rs` and the kernel
    source are not compiled into the binary at all.
* **A gpu-metal build** uses `metal.rs:96-109`:
  * it reads `std::env::var("HL_GPU")` on **every call**;
  * it is true only for exactly `"1"`;
  * otherwise it returns `false` before calling `ctx()`.
* **With `HL_GPU=1`**, `enabled()` calls `ctx()` (`:70-88`). `ctx()` initialises a `OnceLock` once per process: the
  system device, `new_library_with_source(SRC)` (`:75`), 18 pipelines and the command queue. Its `Ok` / `Err` is
  fixed for the life of the process.
  * `Ok` → `true`.
  * `Err` → `false`, or a panic if `HL_GPU_REQUIRED=1` (`:102-105`).
* **Can it change during a process?** Yes, if something calls `std::env::set_var` / `remove_var` on `HL_GPU`. Six
  `#[ignore]`d tests do, and each says "run alone by name". The `ctx()` result itself never changes.
* **`HL_GPU_REQUIRED`** never routes work to Metal (`gpu/mod.rs:48-74`). Its effects:
  * with `HL_GPU` unset, `enabled()` is still false;
  * `require_live()` errors;
  * a decline panics.

### Every call site from the prover, the commitment and the sumcheck into the Metal backend

**1. The commitment seam.** This is the only route from `zkp-core`'s commitment into Metal.

* hashline's `pcs.rs` passes `gpu::backend()` to these functions (`:36-38`, `:107-116`):
  * `zkp_core::pcs::commit_with`;
  * `commit_zk_owned_with`;
  * `commit_zk_owned_with_tag`.
* In a Metal build, `backend()` is `MetalBackend` (`gpu/mod.rs:743-813`). All three of its methods return `None` first
  when `!enabled()` (`:774`, `:786`, `:798`). Only then do they call `metal_commit` / `metal_commit_zk`.
* `zkp-core` builds a `Store::Device` only from a `Some` (`zkp-core/src/pcs.rs:220-223`, `:731-733`, `:778-783`).
* `MetalCommit::fold_rows` / `columns` (`metal.rs:673`, `:703`) run only on such a store (`zkp-core/src/pcs.rs:316`,
  `:428`, `:968-969`, `:1040`).
* The other two hashline routes to a device store are gpu-cuda only: `commit_planes` (`pcs.rs:58-85`) and
  `commit_zk_device` (`:123-138`).

**2. The private-block slot sumcheck.**

* `argument()` computes `metal_on = Prove && gpu::enabled()` once per block proof (`argument.rs:2636`).
* Only under `metal_on` does it build an IR on a cloned transcript and set `def.metal` (`:2661-2697`; the only setter
  is `:2688`; the default is `metal: None` at `:1337-1338`).
* All three Metal calls need `def.metal` to be `Some`:
  * `MetalTables::new` (`:899-907`);
  * `metal_rounds_owned` (`:976-998`);
  * `metal_rounds` (`:1000-1025`).
* The verifier never has `metal_on`.
* `metal_slot.rs` and `slot_ir.rs` contain no `crate::gpu` call.

**3. Every other `crate::gpu` device call** in `zk.rs`, `layer.rs` and `wcache.rs` sits under
`#[cfg(feature = "gpu-cuda")]`:

* `zk.rs:1047-1058, 1354, 1431, 1564, 1633, 2761-2790, 2986, 3072, 3382, 3472, 3563`;
* `layer.rs:224, 504, 596, 745, 803, 1491, 1753, 1826`;
* `wcache.rs:307`.

These calls name `dev_*` symbols that exist only under gpu-cuda (`gpu/mod.rs:76-118`), so they cannot be compiled
into a Metal build.

**4. What is left of the Metal surface.**

* `stats`, `pool_stats`, `sumcheck_stats` and `batch_stats` read atomic counters only.
* `probe_field` and the `*_for_test` hooks are used only by tests (`slot_ir_accuracy.rs`, `tests/zk60_metal_commit.rs`).
* `fold_rows_host_lazy` is re-exported only under `cfg(test)` (`gpu/mod.rs:37-38`).
* Every device-touching function calls `ctx()`. I found no lazily initialised backend, no feature-gated default and no
  fallback that reaches Metal without going through `enabled()`.

**5. `trained_block.rs:2597-2605` (`backend_of_this_process`)** returns `BACKEND_CPU_BUILD` at `:2599` in any build
without gpu-cuda. So in a Metal build `enabled()` at `:2600` is never reached, and this function gates no device path.

### Could `metal.rs` have influenced a byte when `proved_on_gpu` is false?

* **A receipt byte: no.** This assumes `HL_GPU` did not change during the process.
  * With `enabled()` false, no commitment has a Metal store and no slot has `def.metal`. No byte of `metal.rs`'s
    arithmetic runs.
  * The two remaining entries are `enabled()` and `label()`. Neither writes into a transcript.
* **A byte in the bundle: yes, one constant string (W-3).**
  * With `HL_GPU` unset, `label()` returns this file's literal `"gpu: off (built with gpu-metal; HL_GPU unset)"`
    (`:113-115`).
  * With `HL_GPU=1` and a device that failed to initialise, it returns `"gpu: off (Metal unavailable: {e})"` (`:122`).
  * The D60 writer test puts `label()` into the README note (`run_fork_tests.rs:1175-1178`). The writer stores that
    note in `README.md`, which the manifest lists and hashes (`run_capture.rs:4460-4464`).
  * I confirmed the string in all four retained READMEs.
  * It is build or device metadata, not private data.

### Verdict

**SAFE at the CPU-path scope for receipt bytes.** In a CPU-made bundle, `metal.rs` decides one public README string
through `label()`, and nothing else. The device paths were not read and are out of scope. A GPU-made bundle stays
refused.

### Where I differ from the self-reading

* It says: "With enabled() false this file computes no byte of a receipt or a bundle." The receipt half holds. The
  bundle half does not: `label()` puts `metal.rs`'s own string into every fresh bundle's `README.md` (W-3). The JSON
  even cites the note (`run_fork_tests.rs:1177`), but the verdict line does not count it.
* It lists `trained_block.rs:2600` among the places "every device path of the prover is gated on". In a Metal build
  that line is never reached, and it gates no device path (W-5, Info).
* It does not say that the store methods `fold_rows` / `columns` carry no `enabled()` check of their own. They are
  safe only because the store exists only after a gated commit. This matters only together with W-2.
* The rest agrees. I confirmed every gating line it cites.

---

## Pin 3: `src/gpu/metal_kernels.metal` at `be968236`, CPU-path scope

### What I read

* The file's only uses, all in `metal.rs`:
  * `SRC = include_str!(…)` (`:31`);
  * the library compile inside `ctx()` (`:75`);
  * `gl_header()` (`:1113-1115`).
* `gl_header()`'s callers:
  * `sc_pipelines` (`:1218-1222`), which needs a `&Ctx` and is reached only from the slot paths above;
  * two test benches (`:516-520`, `:548-553`).
* A grep found no other use in the crate.

### Could it have influenced a byte when `proved_on_gpu` is false?

* **With `HL_GPU` unset (the four fresh bundles): no.** The source is a string constant that nothing reads; it is
  never compiled or run.
* **With `HL_GPU=1` and a device that fails to initialise:**
  * `ctx()` does compile, or try to compile, the source;
  * `enabled()` is false, so `proved_on_gpu` is false;
  * a compiler error message could reach the README through `label()` (W-4, Info);
  * no receipt byte is affected.

### Verdict

**SAFE at the CPU-path scope.** The kernel code itself was not read.

### Where I differ from the self-reading

* It says "never compiled or executed" on a CPU-made bundle. That is exact only with `HL_GPU` unset (W-4). The four
  bundles had `HL_GPU` unset.

---

## Findings, ranked

**W-1 (Medium; latent, none of the round-26 admitted bundles is affected).** In `write_bundle`, `proved_on_gpu`
records the capture process, not the prover.

* `run_capture.rs:4587` writes `gpu::enabled()` of the capture-test process. Token-I/O and classifier captures can
  prove in a child CLI process (the call sites under pin 1). The classifier and gate-19 captures always do.
* A gpu-metal CLI binary run with `HL_GPU=1`, captured by a no-feature test build, yields `proved_on_gpu: false` for a
  receipt partly made on Metal.
* Nothing in the run can contradict it. `backend_of_this_process` (`trained_block.rs:2597-2605`) labels every
  gpu-metal build `"gpu: off (built without --features gpu-cuda)"`, even when Metal is live. So the CLI statement's
  `prover_reported.backend` cannot reveal Metal use either.
* Recommendation, to do before the backend rule is applied to token-I/O or classifier bundles (today it is applied
  only to W16 and D55 bundles, which are proved in-process), use one of these:
  * have the prover record its own backend and copy that value into the manifest (with a Metal-aware backend name in
    `trained_block.rs`);
  * mark the field UNKNOWN when the proof came from another process.

**W-2 (Low).** `enabled()` is re-read from the environment on every call, not latched per proof.

* Where it is read: `metal.rs:97`.
* Six `#[ignore]`d tests toggle `HL_GPU` in-process:
  * `slot_ir_accuracy.rs:1471-1529, 1580-1598, 1613-1667`;
  * `w16_privacy_gate_tests.rs:1431-1443` via `:1528` and `:1861`;
  * `w16r2_tests.rs:308-316, 1940-1988`.
* The prover reads `enabled()` in two places:
  * the commitment seam reads it on each commit;
  * the slot path reads it once per block.
* A device store's `fold_rows` / `columns` then run with no check at all.
* If a writer test shares a process with a toggling test, its bundle can be partly Metal-made and still say `false`,
  or the reverse. Two ways this can happen:
  * `--ignored` without `--exact`;
  * `--include-ignored` with more than one test thread.
* The four bundles avoided this (`--exact --test-threads=1`, `HL_GPU` unset).
* Recommendation, either:
  * latch the backend once per proof;
  * or, before writing `false`, check that the Metal counters did not move during the run: `metal_stats().0`,
    `metal_sumcheck_stats()` and `gpu::declines()`.

**W-3 (Low; a wording correction to a gate record, no privacy effect).** `metal.rs` does write bytes into a CPU-made
bundle.

* `label()` (`:113-115`) puts its constant string into `README.md` through the D60 writer test's note.
* The metal.rs reading should say "no receipt byte; one constant README string through `label()`" instead of "no byte
  of a receipt or a bundle".

**W-4 (Info).** `metal_kernels.metal` is compiled when `HL_GPU=1`, even if the device then fails. That can be the case
under `proved_on_gpu: false`. A compiler message could then reach the README through `label()`. No receipt byte.

**W-5 (Info).** The self-reading cites `trained_block.rs:2600` as a gate site. It is unreachable in a Metal build and
gates nothing.

**W-6 (Info).** The assertion at `run_fork_tests.rs:959` compares the manifest with `enabled()` read after the write.
It checks the format, not that the value matches the proof.

**W-7 (Info).** `ALLOWED_KEYS` is one flat list for every file of a bundle. So `"proved_on_gpu"` would now pass PG-7's
allow-list check in `run.json` or a stage file too, not only in the manifest. No writer emits it there today.

**W-8 (Info, agrees with the self-reading).** The classifier's five pins now sit two places later. The readers key
pins by file name, so nothing misreads.

**W-9 (Info, pre-existing, not changed by this diff).** Pins are read from disk when the bundle is written
(`run_capture.rs:4618-4626`), not taken from what was compiled. `metal_kernels.metal` is embedded at build time by
`include_str!`, so an edit between the build and the write would pin a file the binary does not contain. The round-26
record says no Rust file changed after its build.

**W-10 (Info, outside the three pins).** The module comment at `src/pcs.rs:13-17` says `DevStore` is `NoExternal`
without gpu-cuda. Under gpu-metal it is `MetalCommit` (`gpu/mod.rs:751`). `gpu/mod.rs:16-17` has the same stale
wording.

## What this check did not do

* It did not read the Metal device code (the commitment kernels, `MetalRounds`, the fold) or the kernel source as
  code.
* It did not run or rebuild anything.
* It read the Python gate only for two things: the backend rule and how pins are keyed.
* The readings of the supporting files (`gpu/mod.rs`, `argument.rs`, `zkp-core/src/pcs.rs`, `trained_block.rs`) are
  the other readers' work. I used those files only to trace call sites at the digests the bundles pin.
