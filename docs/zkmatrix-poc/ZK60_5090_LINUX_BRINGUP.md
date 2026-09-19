# The RTX 5090 on its own Linux box — bring-up, byte gates, and the measurement ladder

Status: **Reviewed by the orchestrator (Claude Fable 5.1), 2026-09-19 12:40;
section A sent to Victor.** Drafted by a delegated Opus agent. I read section
A line by line and the agent's summary of B–E; the commands in B–E are the
agent's derivations from this repository's scripts, each with its source path
beside it, and have **not** been run anywhere — treat the first execution on
the new machine as their test. Two additions of mine:

1. **Driver flavour (step A.3).** Consumer Blackwell cards are supported only
   by NVIDIA's **open** kernel modules. `sudo ubuntu-drivers install` normally
   picks the right package, but if `nvidia-smi` afterwards prints "No devices
   were found" or the card is missing, the proprietary flavour was installed:
   run `sudo ubuntu-drivers list`, then install the newest entry whose name
   ends in `-open` (for example `sudo apt install nvidia-driver-570-open` or a
   higher number) and reboot. [From my own knowledge of the 50-series
   launch, not from this repository — verify against NVIDIA's current
   release notes on the day.]
2. **The decision the draft left to me (§C.2, arm b).** Arm (b) must turn off
   **every** kernel lever, so that "defaults minus (b)" is what the kernel
   work bought at the 8B shape: the three pre-lane-AO switches **and**
   `HL_GPU_P1_COMPACT=0` (this morning's `fsp-l9` fusion). Each lever's own
   contribution is then taken separately in §C.6. An arm (b) that leaves the
   fusion on would measure a mixture that answers no question.

## 0. What this page is, and what it replaces

`BLACKWELL_5090_RUNBOOK.md` was written for a different plan: the card
going into the WSL laptop's successor, with the NVIDIA driver installed
**Windows-side first** because "the WSL GPU stack takes its driver from the
host" (§3a). Victor has since decided otherwise: **the 5090 goes into a
separate machine running plain Linux**, at least 200 GB of disk, system RAM
not yet known.

That changes four things and nothing else:

1. The driver is installed **on the Linux box itself**, by the
   distribution's own route — there is no Windows side any more.
2. The CUDA toolkit is a **real toolkit at `/usr/local/cuda-12.8`**, not the
   pip-assembled symlink farm at `/home/victor/cuda-root` that this laptop
   uses (`ls -la /home/victor/cuda-root/lib64` shows four symlinks into
   `~/.local/lib/python3.10/site-packages/nvidia/...` and
   `/usr/lib/wsl/lib`). Every `LD_LIBRARY_PATH` in this repository's archived
   scripts carries those two WSL-only entries and they must be dropped.
3. The **whole-machine freeze risk disappears** (§C.0) — but the rest of the
   GPU discipline does not.
4. Everything after "the machine boots, `nvidia-smi` works and I can SSH in"
   is the agent's, not Victor's.

Everything else in the runbook still holds and is not repeated here: the
Amdahl warning (§2), the driver-before-toolkit order and the **quiet CPU
fallback** it produced (§3a), byte gates before timings (§4), the ≤ 600 W
ruling (§5), and what the card does and does not settle (§6).

Companions: `ZK60_CLAUDE_5090.md` (the prepared qualification campaign, task
CL11 — its preflight and its staged plan are used verbatim below),
`MEASUREMENT_PROTOCOL.md` (p95 over ≥ 20 warm runs on an idle machine),
`TARGET_CONTRACT.md` §3–§4 (the clock and the power bound),
`ZK60_FIVE_SECOND_PLAN.md` §4–§6 (what the card is projected to buy, and
lane 1's three-arm measurement), `ZK60_PRIVATE_FFN_COST_PROBE.md` §3
(the private ladder a 32 GB card makes safe).

**Reference point for everything below.** The best measured public-IO 8B
feed-forward proof on this laptop's RTX 4070 (8,188 MiB):

| fact | value | source |
|---|---:|---|
| prove | **58.40 s** | `results/hashline_convert_r3.log:542` |
| witness load + chain (outside the prove clock) | 134.50 s | same line |
| verify | 1.08 s | same line |
| proof | `dc980e81…4536c`, **1,234,936,956 B** | `results/hashline_convert_r3.log:540` |
| VRAM peak | 5,249 MB | `:538` |
| host peak RSS | 4,689,216 kB (≈ 4.47 GiB) | `:545` |

## A. Victor's part — one page, in order

Five steps. About **an hour and a half** in total, most of it waiting for an
installer. After step 5 you can close the lid and everything else happens
over SSH.

---

**1. Install Ubuntu 24.04 LTS Server.** ~30 minutes.

Download `ubuntu-24.04.x-live-server-amd64.iso`, write it to a USB stick,
boot the new machine from it, accept the defaults, and give the whole disk
(at least 200 GB) to a single ext4 root.

*Why 24.04 Server and not something newer or prettier:* NVIDIA publishes a
CUDA apt repository for `ubuntu2404`, which is the route step 3 uses; the
release is supported to 2029; and its Python is 3.12, comfortably above the
3.10 the project's helper scripts need
(`scripts/hashline_cl_gpu_gates.py` notes a Python-3.10 syntax constraint
at line 191). **Server, not Desktop**, for one measurable reason: a desktop
session holds video memory, and this project's own idle gate requires the
card to read **≤ 1,024 MiB used with no compute processes** before any run
(`ZK60_CLAUDE_5090.md:45`). A headless box reads 0 MiB and never argues.
*(Inferred: that a newer LTS would also work but may not yet have an NVIDIA
CUDA repository. If 24.04 is unavailable, tell the agent which release you
installed before it starts step B.3.)*

*If the disk is an NVMe SSD, say so.* Today's 8B pass spends **134.50 s**
loading the witness from disk before the 58.40 s of proving
(`results/hashline_convert_r3.log:542`), so storage speed is visible in the
wall clock.

**It worked when:** the machine boots to a login prompt and `ip a` prints an
address on your network.

---

**2. Make a user for the agent and turn on SSH.** ~5 minutes.

```
sudo apt update
sudo apt install -y openssh-server
sudo adduser victor
sudo usermod -aG sudo victor
```

Then paste the public key the agent gives you into
`/home/victor/.ssh/authorized_keys` (the agent will hand you one line of
text and the exact command).

*Call the user `victor` and nothing else.* One file in the prover
(`hashline/src/export.rs:38-42`) falls back to the literal path
`/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl` when an
environment variable is unset, and dozens of archived commands in this
repository contain `/home/victor/...`. Matching the layout costs nothing and
removes a whole category of "it ran but read the wrong directory".

**It worked when:** from your laptop, `ssh victor@<address>` logs in without
a password prompt for the key.

---

**3. Install the NVIDIA driver.** ~10 minutes plus a reboot.

```
sudo ubuntu-drivers install
sudo reboot
```

then after it comes back:

```
nvidia-smi
```

*Why this and not a manual `.run` installer:* the distribution route keeps
the kernel module rebuilt across kernel upgrades. The card needs driver
**570 or newer** — `BLACKWELL_5090_RUNBOOK.md:92` records that the 56x
branch does not support consumer Blackwell at all, and §3a of that page
records what happens when the toolkit is ahead of the driver: the prover
silently falls back to the CPU **and still prints `PASS … ACCEPT`**.

**It worked when:** `nvidia-smi` prints a table whose first row says
**NVIDIA GeForce RTX 5090**, whose driver version is **570.x or higher**,
and whose Memory-Usage column reads close to **0 MiB**. Send the agent a
copy of that output.

---

**4. Tell the agent four things.** ~1 minute.

* the hostname or IP address,
* the username (`victor`),
* the output of `free -g` (this is the system RAM question — see D.3; 64 GB
  is comfortable, 32 GB is workable, 16 GB is the floor the project's own
  preflight enforces for this shape),
* the output of `nvidia-smi` from step 3.

---

**5. Stop.** Everything after this — CUDA toolkit, Rust, the clone, the
builds, copying 7 GB of model exports off the laptop, the twelve byte gates,
and every measurement — is the agent's, over SSH, and is written out in
section B. You will be asked for exactly two more things later, both
optional: `sudo` for the CUDA toolkit install (the agent has it via step 2),
and a decision about whether to take a `nvidia-smi -pl 450` comparability
row (§C.3), which the contract no longer requires.

## B. The agent's part, over SSH

Twelve steps, each with the command and the check that says it worked. The
order of B.3 → B.4 → B.8 is **forced** by `BLACKWELL_5090_RUNBOOK.md` §3a
(driver, then toolkit, then the crate's CUDA binding) and must not be
rearranged.

Conventions used below and set once at the top of every shell:

```
export R=/home/victor/IntelligenceRegulation
export CUDA_ROOT=/usr/local/cuda-12.8
export CUDA_LD=/usr/local/cuda-12.8/lib64
export EV=$R/results/zk60_5090_bringup
mkdir -p $EV
```

`CUDA_LD` is the new box's replacement for the WSL value
`/home/victor/cuda-root/lib64:/home/victor/.local/.../cuda_nvrtc/lib:/usr/lib/wsl/lib`
that appears in `results/cl1_floors.sh:139`, `results/hashline_hostwall_floors.sh:10`
and every lane script. **Both WSL entries are dropped**; on native Linux
`libcuda.so.1` comes from the driver and is already on the loader path.

Everything this section writes goes under `$EV`, i.e. under `results/`,
never `/tmp` — proof captures in `/tmp` die on reboot and are
unreproducible (the project's standing `env-tmp-evidence-loss` rule; the
private-cost probe restates it at `ZK60_PRIVATE_FFN_COST_PROBE.md:620-622`).

---

### B.1 Record the machine before changing it

```
nvidia-smi --query-gpu=name,driver_version,memory.total,pcie.link.gen.max,pcie.link.width.max --format=csv > $EV/machine-gpu.csv
uname -a > $EV/machine-kernel.txt
grep -m1 'model name' /proc/cpuinfo > $EV/machine-cpu.txt
nproc >> $EV/machine-cpu.txt
grep MemTotal /proc/meminfo > $EV/machine-mem.txt
df -h / > $EV/machine-disk.txt
```

The `name,driver_version` pair is the query `results/cl1_floors.sh:255` runs
into its manifest; the rest is the same fact set
`scripts/hashline_benchmark.py:299-308` records automatically into every
run manifest (`platform`, `machine`, `cpu`, `logical_cpus`). The PCIe
columns are **inferred** additions — no script in this repository reads
them, and §D.5 explains why they matter here.

**Acceptance:** GPU name contains `5090`; driver ≥ 570.00; `MemTotal`
recorded (this is the number §D.3 is judged against).

---

### B.2 Base packages

```
sudo apt update
sudo apt install -y build-essential git curl pkg-config rsync python3
python3 --version
```

Nothing exotic is needed: `scripts/hashline_cl_gpu_gates.py` and
`scripts/hashline_cl_5090_preflight.py` import **only the standard library**
(argparse, hashlib, json, os, re, subprocess, fcntl, …), so there is no
Python environment to build.

**Acceptance:** `python3 --version` ≥ 3.10.

---

### B.3 The CUDA toolkit — 12.8, and 12.8 specifically

Install the toolkit from NVIDIA's `ubuntu2404` CUDA repository, selecting
the versioned metapackage `cuda-toolkit-12-8` (**not** `cuda`, which pulls
a driver and could downgrade the one Victor installed).

Two facts pin the version:

* `sm_120` codegen lands in **CUDA 12.8** — `BLACKWELL_5090_RUNBOOK.md:93`.
* `cudarc 0.13.9`'s highest CUDA feature is **`cuda-12080`**
  (`~/.cargo/registry/src/*/cudarc-0.13.9/Cargo.toml:110-117` lists
  `cuda-12000` … `cuda-12080` and stops). A newer toolkit would have no
  matching binding, and the project's preflight refuses anything but
  `cuda-12080` on Blackwell (`scripts/hashline_cl_5090_preflight.py:96`).

**Acceptance, three checks, all required:**

```
test -f $CUDA_ROOT/include/cuda.h && echo "cuda.h OK"
ls $CUDA_ROOT/lib64/libnvrtc-builtins.so.12.8
$CUDA_ROOT/bin/nvcc --version
```

* `include/cuda.h` is what `cudarc`'s build script searches for — without
  it the GPU build fails with *"Unable to find `include/cuda.h` under any
  of: …"* (`cudarc-0.13.9/build.rs:98-107`).
* `lib64/libnvrtc-builtins.so.12.8` is the exact filename the project's
  preflight globs to decide the toolkit version
  (`scripts/hashline_cl_5090_preflight.py:180-190` matches
  `libnvrtc-builtins\.so\.(\d+\.\d+)$` under `<cuda-root>/lib64`). If the
  packaged name carries a patch suffix, the versionless symlink must exist
  or the preflight reports `nvrtc_version: null`.
* `nvcc` itself is **not** used to build anything here — see §D.2: the CUDA
  kernels in `hashline/src/gpu/kernels.cu` are compiled **at run time by
  NVRTC**, from the compute capability the device reports. `nvcc --version`
  is only a witness that the toolkit is the version we think it is.

---

### B.4 The one source change the new card needs

`hashline/Cargo.toml:35` selects `cudarc`'s `cuda-12040` binding — the one
that matches this laptop's toolkit. On the 5090 box it must read
`cuda-12080`:

```
cudarc = { version = "0.13", default-features = false, features = ["driver", "nvrtc", "cuda-12080", "dynamic-linking", "std"], optional = true }
```

Three things about this change, all load-bearing:

1. **It is the third step of the runbook's forced order**, not the first.
   `BLACKWELL_5090_RUNBOOK.md:136-141`: "Deliberately NOT bumped ahead of
   the driver: that feature selects the driver-API binding, so moving it
   under a 566 driver is the same class of mistake in the other direction."
2. **It must be committed before the gates can run.**
   `results/cl1_floors.sh:252-253` aborts with *"uncommitted changes under
   hashline/ … the manifest can never be green; commit first — nothing was
   built"*. So: make the edit on a named branch, commit it, and run the
   gates against that commit.
3. **It must not move a single proof byte.** It changes which driver-API
   binding is compiled in, not any kernel. If a digest moves after this
   edit, that is §D.1 territory — stop.

`arch_str` needs **no** change: `hashline/src/gpu/cuda.rs:569-570` already
carries `(10, 0) => "compute_100"` and `(12, 0) => "compute_120"`, added by
lane AJ precisely for this card.

**Acceptance:** `git --no-pager diff HEAD --stat` shows one file, one line;
after the commit, `git --no-pager status --short` is empty.

---

### B.5 Rust

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
/home/victor/.cargo/bin/rustc --version
```

* **There is no `rust-toolchain` or `rust-toolchain.toml` anywhere in this
  repository** (checked with `find -maxdepth 2`), and every crate declares
  only `edition = "2021"`. The toolchain is therefore whatever stable is
  installed; this laptop's archived builds all ran **rustc 1.97.1 /
  cargo 1.97.1** with `profile = minimal`, `default_toolchain = stable`
  (`~/.rustup/settings.toml`). Match that or newer.
* **Always call `/home/victor/.cargo/bin/cargo`** — the rustup shim. The
  project's standing environment note (`env-rust-toolchain`, 2026-08-17) is
  that calling the toolchain-directory cargo directly picks up a rustc that
  rejects `--check-cfg` and fails the build. Lane scripts already do this
  explicitly: `CARGO=/home/victor/.cargo/bin/cargo`
  (`git --no-pager show fsp-l9:results/fsp2_build.sh`).

**Acceptance:** `rustc --version` ≥ 1.97.1.

---

### B.6 Clone

```
git clone <the repository URL> /home/victor/IntelligenceRegulation
git --no-pager -C /home/victor/IntelligenceRegulation checkout <branch the orchestrator names>
git --no-pager -C /home/victor/IntelligenceRegulation rev-parse HEAD
git --no-pager -C /home/victor/IntelligenceRegulation status --short
```

The clone is small — `.git` is 140 MB on this box and the tracked tree is
source and documents. **It does not contain the model exports**: every
`*.bin` under an export directory is gitignored (e.g.
`results/m125_ffn_export_wsl/.gitignore` is one line, `*.bin`, and
`git ls-files` on that directory returns exactly four sidecars). That is
what B.9 is for.

**Acceptance:** HEAD equals the commit the orchestrator named; `status
--short` prints nothing.

---

### B.7 The first networked build — CPU binary

```
/home/victor/.cargo/bin/cargo build --release --locked --manifest-path $R/hashline/Cargo.toml
```

**`--locked`, and no `--offline`.** Every archived build on this laptop runs
`--offline` (`results/fsp2_build.sh`; `results/cl1_floors.sh:316,326,346`)
because `~/.cargo/registry` here is already populated (380 MB). There is
**no vendor directory and no `.cargo/config.toml`** in this repository or in
`~/.cargo` — `--offline` works purely off that warm registry cache. A fresh
machine has neither, so the first build must be networked.

It is still reproducible: `hashline/Cargo.lock` pins **39 packages** with
**36 `checksum` lines** (the three without are the path crates `hashline`,
`zkp-core`, `private-block-kernel`), and `zkp-core/Cargo.lock` pins 24 more.
`--locked` makes cargo refuse to rewrite either lockfile rather than
resolving something newer, so the fetched versions are exactly the ones this
laptop built. After this first build succeeds, `--offline` may be added to
every later build, exactly as the archived scripts do.

**Acceptance:** `$R/hashline/target/release/hashline` exists and
`$R/hashline/target/release/hashline gpu-probe` prints
`gpu: off (built without --features gpu-cuda)` before exiting non-zero —
that refusal is the CPU binary behaving correctly
(`hashline/src/gpu/mod.rs:276-278, 286-288`); the CPU build has no device
arm compiled into it at all.

---

### B.8 The GPU binary

```
CUDA_ROOT=$CUDA_ROOT LD_LIBRARY_PATH=$CUDA_LD CARGO_TARGET_DIR=$R/hashline/target-gpu \
  /home/victor/.cargo/bin/cargo build --release --locked --features gpu-cuda --manifest-path $R/hashline/Cargo.toml
```

This is `results/cl1_floors.sh:276-278` with the WSL paths replaced. The
three environment variables each do one job: `CUDA_ROOT` tells `cudarc`'s
build script where `include/cuda.h` and the link libraries are
(`cudarc-0.13.9/build.rs:153-167` — `/usr/local/cuda` is also a built-in
candidate, so this is belt and braces); `CARGO_TARGET_DIR` keeps the GPU
build in a **separate target directory** so the two binaries are two real
artifacts (`hashline/Cargo.toml:23-24`); `LD_LIBRARY_PATH` puts
`libnvrtc.so.12` on the loader path at run time.

**Acceptance — this is the first real test of the card:**

```
HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD $R/hashline/target-gpu/release/hashline gpu-probe
```

must print a line beginning `gpu: ON — NVIDIA GeForce RTX 5090 (sm_120, …)`
(`hashline/src/gpu/cuda.rs:678`) followed by
`gpu-probe: … mismatches 0`, and must exit 0 — it exits 1 on any field
arithmetic mismatch (`hashline/src/bin/hashline.rs:482-495`).

**It must NOT print** `[UPERF3-AJ] WARNING: … GENERIC PTX`
(`hashline/src/gpu/cuda.rs:599` and `:605`). That warning means the kernels
were compiled without Blackwell codegen and every timing after it is a
measurement of JIT'd generic PTX. Grep for it explicitly.

---

### B.9 The data, copied and verified

Three directories, **≈ 7.0 GB total**, confirmed with `du -sh` on this
laptop on 2026-09-19:

| what | source path on the laptop | size | why it is needed |
|---|---|---:|---|
| Mistral-7B v3-widened export | `/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export` | **6.8 G** | every 8B pass and every single-Mistral-layer rung (C.2–C.6) |
| 125M v3 export | `/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export` | **140 M** | the `v3` and `zkv3` byte gates (`results/cl1_floors.sh:97`) |
| 125M v2 fixture | `/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl` | **59 M** | the `v2` and `zk` byte gates; it is the binary's default `M125_EXPORT_DIR` (`results/cl1_floors.sh:98`, `hashline/src/export.rs:38-42`) |

The Mistral directory holds 258 entries: 32 layers × 8 `.bin` files, plus
`digests.txt` (25,015 B) and `manifest.json`. Its manifest records
`t 512, d 4096, f 14336, layers 32`, `profile v3-widened`, checkpoint
`/home/victor/models/Mistral-7B-v0.1`.

**Copy them to the same absolute paths** (create
`/home/victor/wt-uperf3-aa/results/m8b_test/` on the new box) so every
archived command in the repository runs verbatim:

```
rsync -a --info=progress2 /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export/ victor@<host>:/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export/
rsync -a --info=progress2 /home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export/ victor@<host>:/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export/
rsync -a --info=progress2 /home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl/ victor@<host>:/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl/
```

*(`rsync` invocation is **inferred** — no archived script copies these
between machines. The paths, sizes and the fact that only the sidecars are
tracked in git are all verified.)*

**Verification is built into the prover and does not need a separate tool.**
`hashline/src/export_v3.rs:231-250` recomputes the SHA-256 of every
`X / WgT / WuT / WdT` and every `a16 / u16 / h16 / z16` plane as it loads it
and asserts it against the sidecar — *"layer {l} {name}: export digest
mismatch"* — and `export.rs:49-60` does the same for the v2 fixture. So a
truncated or corrupted copy cannot pass silently; it panics on the first
layer. A cheap explicit check first:

```
diff <(ssh victor@<host> 'sha256sum /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export/digests.txt') <(sha256sum /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export/digests.txt)
```

**What is NOT copied:** `/home/victor/models/` — **39 GB** of raw
checkpoints (`Mistral-7B-v0.1`, `125m-best-adamw-val3.0816`, `fineweb-edu`,
`gemma-4-12B-qat`). They are needed only to *re-export*
(`scripts/m8b_export_ffn.py`, `scripts/m125_export_ffn.py`), which nothing
on this ladder does. Also not copied: the ~20 sibling worktrees under
`/home/victor/wt-*`, whose `results/m8b_test` copies are sidecar-only and
would fail on the first read (`ZK60_PRIVATE_FFN_COST_PROBE.md:436-440`).

**Acceptance:** the three directory sizes on the new box match
`6.8 G / 140 M / 59 M`; `digests.txt` digests match; and B.10 loads them
without a digest-mismatch panic.

---

### B.10 The byte gates — twelve, at full SHA-256, before any timing

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock /home/victor/IntelligenceRegulation/results/cl1_floors.sh --repo /home/victor/IntelligenceRegulation --cuda-root /usr/local/cuda-12.8 --cuda-ld /usr/local/cuda-12.8/lib64 --v3-export /home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export --m125-export /home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl --threads 2 --build-jobs 2 --rayon-threads 2 >> /home/victor/IntelligenceRegulation/results/zk60_5090_bringup/floors.log 2>&1; echo $? > /home/victor/IntelligenceRegulation/results/zk60_5090_bringup/floors.done' >/dev/null 2>&1 &
```

`results/cl1_floors.sh` was made portable for exactly this
(`ZK60_CLAUDE_5090.md` §7: *"repository … export dirs, CUDA paths, scratch,
device selection and threads are explicit inputs with the archived values as
defaults; nothing about a checkout is fixed"*). Run it with `--dry-run`
first to see every resolved command without building anything. On a machine
with more than two cores, raise `--threads/--build-jobs/--rayon-threads` —
the default of 2 exists because this laptop is shared.

It runs, in order: parser self-tests; source identity (refusing a dirty
`hashline/` or `zkp-core/`); both builds; the hashline test suite; the
zkp-core tests and its `public_sumcheck` example; the GPU oracle suite
`zk60_gpu_commit` under `HL_GPU_REQUIRED=1`; the two missing-feature
controls; **the twelve byte gates**; the three weight-cache cases; and a
`finalize` that re-probes the tree.

The twelve gates are the four frozen fixtures at `pass 12 512` on three
arms — CPU binary, GPU binary, GPU binary with the hiding commitment's
chunking forced (`HL_ZK_CHUNK=1`, `results/cl1_floors.sh:434`). The frozen
expectations live in one place,
`scripts/hashline_cl_gpu_gates.py:110-113`:

| gate | arguments | sha256 | bytes |
|---|---|---|---:|
| `v2` | *(none)* | `50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d` | 66,844,928 |
| `v3` | `--profile v3 --export <125M v3>` | `5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d` | 70,758,084 |
| `zk` | `--zk --seed 1` | `021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d` | 87,228,528 |
| `zkv3` | `--zk --seed 1 --profile v3 --export <125M v3>` | `40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17` | 87,697,008 |

A second, simpler runner exists and is worth running too, because its third
arm forces a **different** chunking path: `results/hashline_hostwall_floors.sh`
re-runs the same four fixtures on the GPU binary under
`HL_GPU_CHUNK_BYTES=100000000` and `HL_GPU_CHUNK_ROWS=128`
(`:51-56`) — the small-chunk arm. It hardcodes lane AJ's worktree at line 6
and the WSL `CUDA_LD` at line 10, so it needs two edits or a copy with the
new paths.

**Then the 8B public gate, which the floors script does not cover.** Shape
`32 512` has no frozen expectation inside `cl1_floors.sh`
(`:81-84` — any shape other than `12 512` makes the verdict ungreenable),
so it is run separately, with the digest taken **by hand over the written
file**, which is how every archived 8B run does it
(`results/hashline_zk_8b_pass.sh:28-30`):

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock env HL_GPU=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64 /usr/bin/time -v /home/victor/IntelligenceRegulation/hashline/target-gpu/release/hashline pass 32 512 --profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export --threads 8 --wcache /home/victor/IntelligenceRegulation/results/zk60_5090_bringup/wc8b --proof-out /home/victor/IntelligenceRegulation/results/zk60_5090_bringup/p8b.bin >> /home/victor/IntelligenceRegulation/results/zk60_5090_bringup/gate8b.log 2>&1; sha256sum /home/victor/IntelligenceRegulation/results/zk60_5090_bringup/p8b.bin >> /home/victor/IntelligenceRegulation/results/zk60_5090_bringup/gate8b.log; echo $? > /home/victor/IntelligenceRegulation/results/zk60_5090_bringup/gate8b.done' >/dev/null 2>&1 &
```

(the command line is `results/hashline_convert_r3.log:543` verbatim, with
this box's paths).

**Acceptance — all of it, or nothing proceeds:**

* `floors.log` ends with `ALL CL1 FLOORS GREEN (12 byte gates + …)` and
  `floors.done` contains `0`;
* the manifest at `<scratch>/manifest.json` has a green verdict (the
  validator's, not a grep);
* **`gpu: ON` appears in every GPU gate's log** and `GENERIC PTX` appears in
  none;
* the 8B proof is `dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c`
  at exactly **1,234,936,956 bytes**.

**A digest that differs on new hardware is a BUG, not a hardware finding.**
`BLACKWELL_5090_RUNBOOK.md:178-181`: *"A digest that moves on new hardware is
a Blackwell codegen difference and it is a bug, not a hardware finding; stop
and report it before taking a single timing."* §D.1 lists exactly what to
collect.

---

### B.11 The preflight — the project's own fourteen checks

```
python3 $R/scripts/hashline_cl_5090_preflight.py \
  --repo $R --binary $R/hashline/target-gpu/release/hashline \
  --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export \
  --run-manifest <the floors scratch>/manifest.json \
  --layers 32 --tokens 512 --threads 8 --scratch $EV \
  --privacy P1 --require-cc 12.0 --claim diagnostic \
  --emit-plan --out $EV/preflight.json
```

(`ZK60_CLAUDE_5090.md:22-28`.) This is the gate that mechanically checks
everything B.3–B.10 was supposed to establish, from the box rather than
from a checklist: `compute_capability` 12.0 with a matching `arch_str` arm,
`driver_version ≥ 570`, `nvrtc_toolkit ≥ 12.8`, `cudarc_feature ==
cuda-12080`, `device_idle ≤ 1,024 MiB`, `host_memory` against the band for
the shape, `source_identity` clean, `binary_identity` equal to the
manifest's GPU-binary digest, and `verified_artifact` — a floors manifest
the validator accepts whose HEAD is this HEAD.

`--emit-plan` then writes **the staged measurement commands themselves**,
fully resolved, including their detached wrappers
(`scripts/hashline_cl_5090_preflight.py:645-668`). Section C below is the
narrative of that plan; the emitted plan is the authority on exact argv.

**Acceptance:** exit 0 and `go: true`. Any failure is exit 3 and names the
check and its evidence — fix that, do not proceed.

---

### B.12 The identity file

Fold B.1's outputs, both binaries' SHA-256, the git HEAD, the floors
manifest path and the preflight verdict into one file:

```
sha256sum $R/hashline/target/release/hashline $R/hashline/target-gpu/release/hashline > $EV/binaries.sha256
git --no-pager -C $R rev-parse HEAD > $EV/head.txt
```

`scripts/hashline_benchmark.py` will record the same identity into
`manifest.json` for every measurement run it makes
(`:353-359`: command, binary sha256, export sidecar sha256, GPU
name/uuid/total/driver, CPU model, logical CPUs, platform, and the `HL_*`
environment). This file exists so a reader who has only the bring-up
directory can still answer "which machine, which commit, which binary".

**Acceptance:** `$EV` contains `machine-*.txt`, `binaries.sha256`,
`head.txt`, `floors.log` + `floors.done`, `gate8b.log`, `preflight.json`.

## C. The measurement ladder

Run in this order. Nothing here starts until B.10's gates are green and
B.11's preflight says `go`.

### C.0 The box rules on native Linux — what carries over, what relaxes

**What still applies, unchanged:**

| rule | source | why it survives the move |
|---|---|---|
| **One GPU job at a time**, serialized on `flock /tmp/zk-heavy.lock` | `CLAUDE.md` no-hangup protocol | the reason changes from "or the box freezes" to "or the timing is meaningless" — `MEASUREMENT_PROTOCOL.md` §3 requires an otherwise idle machine, no sibling processes, no suite runs |
| **`nvidia-smi` idle check before each GPU job** — ≤ 1,024 MiB used, no compute processes | `ZK60_CLAUDE_5090.md:45`, `:95-96` | a leftover process still invalidates a number, and the preflight's `device_idle` check still enforces it |
| **Detached, with a `.done` marker** carrying the exit code | `CLAUDE.md` | an SSH session dies as easily as a terminal; the marker is how the next session knows |
| **Evidence under `results/`, never `/tmp`** | `env-tmp-evidence-loss`; `ZK60_PRIVATE_FFN_COST_PROBE.md:620-622` | unchanged |
| **Byte gates before timings; grep every run's header for `gpu: ON`** | `BLACKWELL_5090_RUNBOOK.md` §3a, §4 | the silent-fallback failure mode is a property of the code, not of WSL |
| **Do not wrap `results/cl1_floors.sh` in `/tmp/zk-build.lock`** (self-deadlock; it takes that lock internally) | `results/cl1_floors.sh:66-70` | unchanged |
| **Do not wrap `scripts/hashline_benchmark.py run` in `/tmp/zk-heavy.lock`** — it takes the same lock inside `run_samples` | `scripts/hashline_benchmark.py:287-313`; `ZK60_CLAUDE_5090.md:91-94` | unchanged |

**What relaxes:**

* **The 8 GB ceiling is gone.** Every "must wait for a bigger card" row in
  `ZK60_PRIVATE_FFN_COST_PROBE.md` §3.4 opens: the 32-layer private pass
  (~8.9 GB VRAM [MODEL]) and the legacy private 8B pass that peaked at
  **8,585 MB on an 8,188 MiB card** both fit in 32 GB with room over.
  `scripts/hashline_benchmark.py:262-263` hard-refuses private runs at
  d ≥ 4096 on any card under 16 GiB — on the 5090 that refusal lifts, and
  C.3's private arms become runnable for the first time.
* **The whole-machine freeze is a WSL artefact and does not apply.** The
  repository states the mechanism precisely: *"Under WSL an over-budget
  allocation is served from host memory rather than failing, so it pages
  continuously: the kernel logged `dxgkio_make_resident: Ioctl failed: -12`
  in pairs every ~2 minutes for the whole six-minute run. This box froze
  three times on 2026-09-04"* (`ZK60_FIVE_SECOND_PLAN.md:470-476`). On
  native Linux there is no `dxgk` residency layer: an over-budget
  `cuMemAlloc` returns `CUDA_ERROR_OUT_OF_MEMORY` to the calling process and
  the machine is unaffected. **[Inferred** from standard CUDA-on-Linux
  semantics plus the repository's own framing of WSL as the exception;
  nothing in this repository has been run on native Linux.**]**
* **Chaining GPU passes in one script is therefore no longer dangerous** —
  the "never chain a second GPU pass behind it inside one script" rule
  (`TASK_BOARD.md:656-660`) existed because WSL returns video memory late
  and a retry against a not-yet-released card is how the three freezes
  happened. Keep the separate-jobs-with-an-idle-check form anyway for the
  *timing* runs, because it is also what keeps a warm card from polluting
  the next arm; drop it freely for correctness-only work.
* **The `HL_ZK_DRAIN` / `HL_GPU_CHUNK_ROWS=128` discipline stops being a
  survival measure** and becomes a parameter to measure (C.6). Do not
  change it in the gates: the frozen digests were produced with the
  defaults.

**Power, and the contract.** Read it:

```
nvidia-smi --query-gpu=power.draw,power.limit,enforced.power.limit,power.max_limit --format=csv
nvidia-smi -q -d POWER
```

Cap it, if a capped row is wanted:

```
sudo nvidia-smi -pm 1
sudo nvidia-smi -pl 450
# restore afterwards with the default limit read above
sudo nvidia-smi -pl <default>
```

*(The `-pl 450` invocation is the runbook's own, `BLACKWELL_5090_RUNBOOK.md:196`
and `ZK60_CLAUDE_5090.md:105`; the persistence-mode line and the query
fields are **inferred** standard usage — no script in this repository reads
or sets power.)*

**The contract does not require a cap.** `TARGET_CONTRACT.md` §4 now reads
**≤ 600 W**, amended from 450 W by Victor's console ruling of 2026-09-04
precisely so that a 575 W part is inside it: *"575 W IS FINE — the bound is
amended from 450 W rather than the card being capped to it."* A 450 W row
is **optional**, for continuity with every row measured before that ruling
(stage 5 of `ZK60_CLAUDE_5090.md` §3), and must be labelled as such.

---

### C.1 The 12 × 512 fixtures, public and zero-knowledge

**Command shape** (this is a gate command from `results/cl1_floors.sh:437,451-454`
with the new box's paths; B.10 already ran it for bytes, this runs it for
seconds on a quiet box):

```
env HL_GPU=1 LD_LIBRARY_PATH=$CUDA_LD M125_EXPORT_DIR=$R/results/m125_ffn_export_wsl \
  $R/hashline/target-gpu/release/hashline pass 12 512 --threads <N> \
  --profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export \
  --proof-out $EV/c1_v3.proof
```

and the zero-knowledge arm, the same line plus `--zk --seed 1`.

**Writes:** two proofs (70,758,084 B and 87,697,008 B) and two logs.
**Takes:** seconds per run; the whole rung is a couple of minutes.
**Answers:** does the card produce the right bytes at all, and what is the
first speed ratio against the laptop?

**The 4070 anchors** [MEASURED, from the byte-gate logs
`results/cl18_frozen_gates.log` and `results/floors_round16_an.log`]:

| arm | RTX 4070 PROVE |
|---|---|
| `v3` public, GPU binary | **2.07 – 2.24 s** |
| `zkv3`, GPU binary | **5.25 – 5.67 s** |
| the same fixtures, CPU binary | 34.8 – 37.4 s |

**[MODEL]: none.** No plan in this repository projects this shape onto a
5090 — every projection is written for the 8B pass. Expect the ratio here
to be **smaller** than C.2's, because fixed host and process costs are a
larger fraction of a two-second run than of a fifty-eight-second one
(**inferred**, not from the plans). Treat a ratio much *larger* than C.2's
as a signal that something is wrong, not as good news.

---

### C.2 The public 8B pass in three arms — lane 1 of the five-second plan

`ZK60_FIVE_SECOND_PLAN.md` §6 lane 1: *"collect what is already paid
for"* — the 8B public-IO pass has never been run since lanes AO and CL7
merged.

**Three arms, one binary, one session, three separate detached jobs:**

| arm | environment | what it is |
|---|---|---|
| (a) | today's defaults | the current tree |
| (b) | `HL_GPU_PAD_SKIP=0 HL_GPU_NTT_FAST=0 HL_GPU_PRUNE_P2=0` | restores the pre-lane-AO kernels exactly (`ZK60_FIVE_SECOND_PLAN.md:812-814`) |
| (c) | today's defaults, **warm** weight cache | run (a)'s command twice against the same `--wcache` directory; the second run is the warm one |

**Command shape** — B.10's 8B gate line with the arm's environment added,
each arm detached under `flock /tmp/zk-heavy.lock`, `/usr/bin/time -v`,
`nvidia-smi` verified idle first, and `sha256sum` taken **by hand** over the
written proof.

*One thing the plan could not know:* this branch also carries lane fsp-l9's
kernel fusion, default ON, restorable with `HL_GPU_P1_COMPACT=0`
(`ZK60_FSP_L9_PROGRESS.md:442`). If arm (b) is meant to be "the tree before
any of this round's kernel work", it should set that too. **Orchestrator's
call** — it changes what arm (b) means, not whether it is byte-identical.

**Writes:** `results/fsp1_*` logs plus three 1,234,936,956-byte proofs
(hash, then delete — 3.7 GB if all three are kept).
**Takes:** on the 4070, each arm is ~197 s wall (134.50 s witness load +
58.40 s prove + 1.08 s verify); three arms plus the extra cold run for (c)
is under half an hour.
**Answers:** do lane AO's kernels transfer to the 8B shape at all; what does
a warm weight cache buy; and **the first real 8B number on a 5090**.

**Gate:** every arm must produce
`dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c` at
1,234,936,956 B. This lane changes no code, so a moved digest means the tree
is broken.

**Expected on the 4070** [COUNTED, `ZK60_FIVE_SECOND_PLAN.md:834-837`]:
(a) ≈ 54 s, (b) ≈ 58 s, (c) ≈ 48 s. *"If arm (a) does not beat arm (b),
lane AO's kernels do not transfer to the 8B shape and step 1 of the plan is
worth nothing — which is itself the most valuable thing this lane could
find."*

**[MODEL] for the 5090**, from `ZK60_FIVE_SECOND_PLAN.md` §4.3, which
applies the project's own Amdahl-by-resource formula to the measured
58.40 s split:

| assumption | 8B public-IO prove |
|---|---:|
| conservative (k_g 4, k_l 1.5) | **27.1 s** |
| mid (k_g 5.5, k_l 2) | **23.1 s** |
| optimistic (k_g 7, k_l 3) | **20.2 s** |
| the same card in a **desktop host** (k_c 2–4) | **14 – 21 s** |
| an *infinitely fast* card, host unchanged | 11.9 s (a hard 4.9× ceiling) |

**Read those with both corrections at the top of §5, which post-date the
table.** (i) Lane `fsp-host` re-derived the host share and found **18–19 s
of the 58.40 s is host work**, not 11.9 s — 72–84% of the counter this
table calls "h2d" is a host packing pass. *"With 18–19 s, a bigger card
alone buys less than §4.3 says … the 10–15 s projection for a 5090 stands
only after the host work lands."* (ii) Lane `fsp-l9` measured step 3 at
**1–2 s, not 7 s**, and put step 1 (arm (a) vs arm (b)) in doubt in either
direction — which is precisely what this rung settles.

So: **the honest expectation band for arm (a) on the 5090 is 20–27 s with
this class of host, and the two corrections push it towards the upper end.**
Anything below ~20 s or above ~35 s deserves an explanation before it is
written down.

**Also record, every arm:** the witness-load time. It was **134.50 s** on
the laptop — 2.3× the prove itself. It sits outside the prove clock, inside
the wall, and **inside the contract clock** as the contract actually defines
it (`ZK60_FIVE_SECOND_PLAN.md` §3.G; `TARGET_CONTRACT.md` §3). A faster NVMe
changes this number and nothing else on the page reports it.

---

### C.3 The contract's measurement — p95 over ≥ 20 warm runs

This is the statistic `TARGET_CONTRACT.md` §4 names and
`MEASUREMENT_PROTOCOL.md` §1 pins, and **it has never been executed at 8B**
(`ZK60_FIVE_SECOND_PLAN.md:787-792`). The collector already exists and
creates no new clock.

**Command shape** (`ZK60_CLAUDE_5090.md:103`, `scripts/hashline_benchmark.py:424-444`):

```
python3 $R/scripts/hashline_benchmark.py run \
  --binary $R/hashline/target-gpu/release/hashline \
  --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export \
  --layers 32 --tokens 512 --threads <N> \
  --privacy P0 --device gpu --warm-runs 20 \
  --out $EV/p0_warm20
```

then the same with `--privacy P1` (stage 3) and, as a **separate** job after
an idle check, `--privacy P3` (stage 4). Three rules:

* `--out` must be a **new** directory; the runner refuses an existing one.
* `LD_LIBRARY_PATH` must be exported in the launching shell — the runner
  copies `os.environ` and sets only `HL_GPU` and `CUDA_VISIBLE_DEVICES`
  itself (`:346-352`).
* the detached wrapper must **not** hold `/tmp/zk-heavy.lock`; the runner
  takes it internally.

**Writes:** `<out>/manifest.json` (command, both binaries' and the export
sidecar's SHA-256, GPU name/uuid/total/driver, CPU model, logical CPUs,
platform, the `HL_*` environment), `cold-000.log`, `warm-001…020.log`, and
one retained `last.proof` (1.23 GB).
**Takes:** 21 runs. At the laptop's ~197 s wall that is **≈ 69 minutes per
arm**; the plan's own estimate is "about 66 minutes — it is affordable, and
it has simply never been scheduled". On the 5090, less.
**Answers:** the first contract-grade number this project has ever had at
8B, with dispersion.

**The statistic, exactly** (`MEASUREMENT_PROTOCOL.md` §1): nearest-rank,
`p = sorted[ceil(q·n)]` 1-based, so with n = 20 warm runs p50 is the 10th
and p95 the 19th order statistic; cold reported separately and never pooled;
min/max printed; **a warm set whose max/min exceeds ~1.5× means
interference — rerun, do not report.**

**Labels** (`ZK60_CLAUDE_5090.md` §5): `[5090-BOX] [QUIET] [MEASURED]`, and
*diagnostic* until coverage is full — FFN-only coverage cannot carry a
target-eligible claim, and the preflight's `coverage_eligibility` check
refuses one.

**Optional stage 5:** repeat the P1 arm at `nvidia-smi -pl 450`, clearly
labelled. Not for the contract (amended to ≤ 600 W); for continuity with
every row measured before the ruling.

---

### C.4 The LEGACY private 8B pass — a cost measurement, not a privacy result

**The label this rung must carry, every time it is reported:** this is the
**legacy** hash-line `--zk` / `--p3` feed-forward path, and the 2026-09-08
correction records **demonstrated private-value disclosure** in it
(`ZK60_FIVE_SECOND_PLAN.md:770-779`). Running it measures the **cost** of
machinery that is going to be replaced. It is not a privacy result and no
number from it may be presented as one.

**Command shape** (`results/hashline_zk_8b_pass.sh:24-30`, paths swapped):

```
env HL_GPU=1 HL_GPU_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD /usr/bin/time -v \
  $R/hashline/target-gpu/release/hashline pass 32 512 --zk --seed 1 --profile v3 \
  --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export \
  --wcache $EV/wc_zk8b --threads <N> --proof-out $EV/zk8b.bin
```

detached under the heavy lock, with `sha256sum` taken by hand afterwards.

**Byte gate:**
`930ce9a043a037210f62ac1384384e3a88607f29046b56284c6308ed272c982e` at
**1,285,578,368 B** — reproduced byte-for-byte on two trees and two device
paths (`TASK_BOARD.md:657-661`).
**Writes:** the 1.29 GB proof, the log (keep it: `HL_GPU_VERBOSE=1` prints
the per-layer VRAM notes), a 129 MB weight cache.
**Takes:** 265.34 s of prove on the 4070 plus the witness load; expect
substantially less.
**Answers:** the card-size question — *"the single cheapest result the
hardware step can produce"* (`BLACKWELL_5090_RUNBOOK.md:225`).

**[MODEL] / [PREDICTION], and the trap.** Two effects, which
`ZK60_FIVE_SECOND_PLAN.md` §4.5 warns *must not be multiplied together*:

1. On the 8,188 MiB laptop card this pass reported **8,585 MB of VRAM** —
   it was already spilling. Layer 0 (which got real video memory) proved in
   **4.36 s**; layers 1–31 in **8.42 s** each. *"A 16 GB+ board should give
   32 × 4.36 ≈ 140 s instead of 265 s with no code change"* — ~1.9×, free
   [PREDICTION, `BLACKWELL_5090_RUNBOOK.md` §6].
2. But CL1's chunking has since brought the private **per-layer** peak to
   5,182 MB with 37% headroom *on the 8 GB card* and one Mistral layer from
   15.82 s to 4.142 s. 32 × that is ≈ **131 s** [PREDICTION] with no new
   hardware at all.

**So: the 5090 either buys ~1.9× here or CL1 already did, and this one run
is what distinguishes them.** A result near 140 s means the card did it; a
result near 131 s reached from a laptop re-run first would mean the code
did. Run it **once**, early, before anything else on this list is
interpreted.

**Per-layer check:** with `HL_GPU_VERBOSE=1`, layers 1–31 must be **no
slower than layer 0**. That, not the total, is the spill going away.

---

### C.5 The repaired private profile's ladder

`ZK60_PRIVATE_FFN_COST_PROBE.md` §3.5 is the ladder; it is reproduced here
only in outline because it is written out there with exact commands.

| rung | what | status on a 32 GB box |
|---|---|---|
| R0 | the repaired profile at width 16, CPU, timed three times | runs today; no seed, no byte gate (fresh OS randomness every run) |
| R1 | 125M, 12 × 512, GPU, three arms (public / legacy `--zk` / repaired) | (a) and (b) run today; (c) **needs tier 1** |
| R2 | the same three arms on the CPU, with `--phase-profile` (refuses on GPU) | as R1 |
| R3 | one Mistral layer, CPU, T = 16, three arms | runs; 7.7 GB host [MODEL] |
| R4 | **one Mistral layer, GPU, T = 512, three arms — the number we actually want** | (a) and (b) run today; (c) **needs tier 1**. ~5.6 GB VRAM [MODEL] |
| R5 | the same with the endpoint arguments on | **needs tier 2/3** and a wire-bound ruling |

**What the new box changes:** §3.4's capacity verdicts. The rows marked
*"Forbidden on this box"* (the 32-layer private GPU pass, ~8.9 GB VRAM) and
*"must wait for a bigger card"* clear on 32 GB. The rows that bind on **host
RAM** do not: one Mistral layer on the CPU at T = 512 is **13.8 GB
[MODEL]** and wants a ≥ 24 GB host; the 32-layer private CPU pass is
> 13.3 GB (legacy measured 13.27–13.97 GB). See §D.3.

**Blocked on code, not hardware.** Arms (c) need the `--mr1` entry point
proposed in §5.1 tier 1, which does not exist. Until that lane lands, C.5 is
two-thirds runnable and the third arm — the only one that answers the
question — is not.

**Answers:** *"whether the private ladder is the public ladder times three
or the public ladder times thirty"* — described in
`ZK60_FIVE_SECOND_PLAN.md:781-785` as worth more than any kernel work on
that page.

**Abort conditions** (`ZK60_PRIVATE_FFN_COST_PROBE.md` §3.6), which still
bind: any `OUT_OF_MEMORY`, any `gpu commit declined`, a moved digest on a
public or legacy arm, and — the one that is not about the machine — **a
`discard attempt` refusal from the repaired path at a new shape: record it
and stop. Never re-run to get past it.**

---

### C.6 The speed lanes' A/B switches, rolled up at the 8B shape

None of these has ever been measured at 8B. Each is byte-preserving by
construction, so each arm must still produce
`dc980e81…4536c` / 1,234,936,956 B.

| switch | default | what `=0` restores | counted worth at 8B | where it is |
|---|---|---|---|---|
| `HL_GPU_P1_COMPACT` | on | lane AO's `k_dit_p1_pad_s` + `k_ntt_p2_gather_sp` pair | **0.8 – 1.8 s** [COUNTED, not measured at 8B] | in this tree (`ZK60_FSP_L9_PROGRESS.md:442`) |
| `HL_FSP4_I128FOLD` | on | the inherited per-element field multiply in `fold_block_i8` | **1.0 – 1.25 s** [COUNTED]; 1.21× GPU / 1.26× CPU on the item at 12 × 512 [MEASURED] | **branch `fsp-host` only** |
| `HL_FSP4_PLANES` | on | the converted `Vec<Fp>` arm of the W commitment | **≈ 9 s** [COUNTED] — the largest single host item | **branch `fsp-host` only** |
| `HL_FSP4_TIMING` | off | — (printing only: the upload's host-pack / bus split) | the instrument that found the packing pass | **branch `fsp-host` only** |

Also withdrawn and kept only for the record, both measured regressions on
the 4070 and **worth re-checking once on Blackwell** because they are
shared-memory bank-conflict changes and the conflict geometry is
architecture-dependent: `HL_GPU_SMEM_SWZ` (0.93× mean) and
`HL_GPU_SMEM_SWZ_PB` (0.91× mean) (`ZK60_FSP_L9_PROGRESS.md:48-50`).
*(That they might behave differently on sm_120 is **inferred**; the lane
withdrew them on measurement, not on theory.)*

**Prerequisite:** the `HL_FSP4_*` switches exist only on branch `fsp-host`
(confirmed: `grep` finds none of them under `hashline/src/` on this
branch). This rung waits for that lane to be integrated.

**Takes:** one 8B pass per arm.
**Answers:** whether ~11 s of counted host and kernel work is real at the
8B shape — which, per the §5 corrections, is the prerequisite for the card
to pay at all.

---

### C.7 What is deliberately not on this ladder

* **L4, fewer hashed bytes.** Its first measured step is `G.1` — a
  rate-only A/B at 12 × 512 using the existing `--inv-rate 2` flag
  (`hashline/src/bin/hashline.rs:70`) against the `--inv-rate 4` baseline,
  with the new digests going into a **separate** table and never into
  `scripts/hashline_cl_gpu_gates.py:110-113`. It is gated on ruling **G.0**
  (δ/3 versus δ/2, and whether 106 bits is per-opening or whole-proof) and
  the whole lever is *"not byte-preserving: it moves every frozen digest in
  the repository"*. It is a ruling, not a bring-up item, and it must not
  share a session with the byte gates.
* **The 32-layer private pass on the CPU** — `ZK60_PRIVATE_FFN_COST_PROBE.md`
  §3.4 says do not run it, and §4.3 explains how to get the 32-layer number
  without it.
* **Stage 6 of `ZK60_CLAUDE_5090.md` §3, the one-GPU inference/proving
  overlap.** *"NOT RUNNABLE in this repository yet"* — there is no
  generation harness; every token here is a prefill row. 60 tokens/s is a
  generation claim and nothing on this ladder measures it.

## D. What could go wrong

Eight failure modes. Each is written as **symptom → the check that catches
it**, because most of them are quiet.

---

### D.1 Silent CPU fallback — the one that has actually happened

**Symptom:** the run completes, prints `PASS … ACCEPT`, the digest is right,
and the time is catastrophically wrong — or, worse, a *correctness* run
passes while proving nothing on the device.
`BLACKWELL_5090_RUNBOOK.md:125-131`: *"the binary did NOT crash. It fell
back to the CPU path and still printed `PASS ACCEPT`, with the reason on one
`gpu: off` line that scrolls past in any real log."*

**Checks, in increasing strength:**

1. `grep -c 'gpu: ON' <log>` on every GPU run. The enabled label is
   `gpu: ON — <name> (sm_120, <N> SMs, <X> GB)`
   (`hashline/src/gpu/cuda.rs:678`); the disabled one begins `gpu: off`.
2. **Machine-checkable and better:** every `pass` prints a
   `HASHLINE_TIMING {…}` JSON line carrying `"gpu_requested"` and
   `"gpu_enabled"` (`hashline/src/bin/hashline.rs:470-480`).
   `gpu_requested: true, gpu_enabled: false` **is** the silent fallback, in
   one grep. `scripts/hashline_benchmark.py:181-188` already rejects any GPU
   row whose `gpu_enabled` is not `true`.
3. For test runs, `HL_GPU_REQUIRED=1` turns a fallback into a failure
   instead of a pass — `results/cl1_floors.sh:377-392` runs exactly this as
   a control, and asserts that a build *without* `--features gpu-cuda`
   FAILS under it, so the gate cannot be vacuous.

Note what the collector cannot do: *"it cannot detect a SILENT fallback"* in
phases after init (`ZK60_CLAUDE_5090.md:150-154`) — `gpu: ON` proves the
device initialised, not that every phase stayed on it.

---

### D.2 A kernel compiled for the wrong architecture

There is **no `nvcc` build step in this project**. `hashline/src/gpu/kernels.cu`
is compiled **at run time by NVRTC**, with the architecture chosen from the
compute capability the device reports
(`hashline/src/gpu/cuda.rs:575-613`). So "wrong architecture" is a run-time
condition, not a build one, and it has two forms:

**Form 1 — no arch arm.** `arch_str` returns `None` and the compile falls
through to generic PTX. **Symptom:** stderr carries
`[UPERF3-AJ] WARNING: compute capability 12.0 has no arch arm in arch_str;
compiling GENERIC PTX (JIT, no 12.0 codegen — timings taken here are NOT
this card's)` (`:599`). Should not happen — `(12, 0) => "compute_120"` is
already there (`:570`).

**Form 2 — the toolkit is older than the card.** NVRTC rejects
`compute_120` and the retry compiles generic PTX:
`[UPERF3-AJ] WARNING: NVRTC rejected arch compute_120 (…); … the toolkit at
CUDA_ROOT is older than this card` (`:605`). This is what a CUDA 12.1
toolkit would do.

**Form 3 — the toolkit is newer than the driver.** The PTX loads nowhere:
`gpu: off (HL_GPU=1 but init failed: cuModuleLoadData:
DriverError(CUDA_ERROR_UNSUPPORTED_PTX_VERSION, …))`, then D.1's silent
fallback (`BLACKWELL_5090_RUNBOOK.md:112-118`).

**Check, all three at once:**

```
grep -E 'GENERIC PTX|UNSUPPORTED_PTX_VERSION|gpu: off' <log>
```
must return nothing on a GPU run, and `HL_GPU_VERBOSE=1` must print
`gpu init: NVIDIA GeForce RTX 5090 (sm_120, …)` (`:615-620`). The
preflight's `compute_capability` check with `--require-cc 12.0` refuses the
first two forms before a run even starts.

---

### D.3 Host RAM too small for the witness load

**The measured facts:**

| workload | peak resident | source |
|---|---:|---|
| public 8B pass, **GPU** path | 4,689,216 kB ≈ **4.47 GiB** | `results/hashline_convert_r3.log:545` |
| private 8B pass (P1), GPU path | 4,556,752 kB ≈ 4.35 GiB | `results/am_r3_8b.log:85` |
| private 8B pass (P3), **CPU only** | 13,972,572 kB ≈ **13.3 GiB** | `results/am_r3_8b_p3_cpu.log:93` |
| one Mistral layer, CPU, T = 512, repaired private | **13.8 GB** [MODEL] | `ZK60_PRIVATE_FFN_COST_PROBE.md` §3.3 |

**The project's own bands** (`ZK60_CLAUDE_5090.md:46`, the preflight's
`host_memory` check): 4 GiB narrow, **16 GiB** FFN-only at d ≥ 4096,
**64 GiB** for full coverage. `BLACKWELL_5090_RUNBOOK.md:96` wants ≥ 64 GB
because that is what brings the 32-layer 8B pass home from the Mac.

**What to tell Victor if he asks what to buy:**

* **64 GB — comfortable.** Everything on this page runs, including the CPU
  arms and full coverage later. This is what the runbook asks for.
* **32 GB — workable.** The entire GPU ladder (C.1–C.4, C.6) fits with
  margin, and the CPU rungs up to one Mistral layer at T = 512 fit.
* **16 GB — the floor, and only just.** The preflight passes for FFN-only
  at d ≥ 4096 and nothing else; the CPU arms are out, and this laptop's own
  13 GiB available is the reason the 8B CPU pass has to run on the Mac.

**Symptom of too little:** the OOM killer, or — far worse for a measurement
— heavy swapping that silently inflates the wall clock without any error.
**Check:** `/usr/bin/time -v`'s `Maximum resident set size` line, which
every archived run already prints, read against the table above; and
`MemAvailable` in `/proc/meminfo` before the run. For deliberately bounded
CPU rungs the project's standing wrapper is
`systemd-run --user --scope -p MemoryMax=<N>G`
(`ZK60_PRIVATE_FFN_COST_PROBE.md:489-492`) — and *"MemoryMax killing the
scope is the designed outcome, not a failure to work around by raising the
cap"*.

---

### D.4 PCIe link width or generation throttling the uploads

**The traffic:** the 58.40 s pass moves **9,328 MB host→device** and
1,411 MB back (`results/hashline_convert_r3.log:538`).

**Symptom:** the `h2d` counter stays as large as the laptop's, or larger,
while every other device phase shrinks. On the laptop that counter reads
**8.597 s for 9,328 MB = 1.08 GB/s effective**, against a separately
measured 5.4–5.6 GB/s raw copy rate (`ZK60_FIVE_SECOND_PLAN.md:525`).

**The trap:** that counter is **not** mostly the bus.
`ZK60_FIVE_SECOND_PLAN.md` §5's first correction block: **72% of it at
12 × 512 (about 84% at 8B) is a host packing pass, `pack_narrow`**. So a
disappointing `h2d` on the new box is more likely a CPU result than a PCIe
result, and the only instrument that separates them is
`HL_FSP4_TIMING=1` — which prints the host-pack / bus split and exists only
on branch `fsp-host` (`ZK60_FSP_HOST_PROGRESS.md:375`).

**Checks:**

```
nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max --format=csv
```
during a run (**inferred** — no script here reads these). Expect the card in
a CPU-attached x16 slot at its full generation; an x8 link, or a chipset
slot, halves the bus and would show up here and nowhere else.

---

### D.5 Thermal or power throttling

**Symptom:** the warm set drifts — later runs slower than earlier ones. The
measurement protocol already catches this without any extra tooling: *"a
warm set whose max/min ratio exceeds ~1.5× on a quiesced box indicates
interference — rerun, do not report"* (`MEASUREMENT_PROTOCOL.md` §1), and
its run order is deliberately **calibration first, heavier last — thermal
honesty** (§3).

**Check — log it alongside the run** (**inferred**; nothing in this
repository logs power or clocks today):

```
nvidia-smi --query-gpu=timestamp,power.draw,temperature.gpu,clocks.sm,clocks_throttle_reasons.active --format=csv -l 1 >> $EV/<arm>-smi.csv
```

started just before the detached job and killed after it. A non-empty
`clocks_throttle_reasons.active` other than `Not Active` during the timed
window disqualifies the row.

**And the contract, restated so nobody caps the card by reflex:**
`TARGET_CONTRACT.md` §4 is **≤ 600 W** since Victor's 2026-09-04 ruling; the
5090's 575 W is inside it; **no cap is required**; the
`BLACKWELL_5090_RUNBOOK.md` §5 cap-and-record paragraph is superseded and
struck through in its own source. A `-pl 450` row is optional comparability
only (C.0, C.3).

---

### D.6 A different CPU changing the host floor — the one that decides the first number

This is not a risk so much as the single largest determinant of what the
5090 reads on day one.

* **18–19 s of the 58.40 s is host work**, re-derived item by item by lane
  `fsp-host` from the run's own verbose lines (`ZK60_FIVE_SECOND_PLAN.md`
  §5, first correction): packing 6.2–7.2 s, matmul folds 5.53 s, conversion
  fill 2.74 s, commit host residual 1.13 s, helpers + H 1.25 s, conversion
  allocation 0.76 s, openings host tail 0.50 s. **No card touches any of
  it.**
* The project's model gives a desktop host `k_c = 2–4`, which is the whole
  difference between §4.3's **20–27 s** (same host CPU) and **14–21 s**
  (desktop host).
* A further **134.50 s** of witness load is host and disk, outside the
  prove clock and inside the contract clock.

**Symptom:** `gpu: ON`, no generic-PTX warning, every device phase down by
the expected factor — and the total barely moves.
**Check:** read the per-phase split the prover already prints with
`HL_GPU_VERBOSE=1` (`results/hashline_convert_r3.log:536-538` shows the
shape: `prover phases`, then
`gpu device-side (summed): h2d … | ntt … | hash … | sumcheck … | fold … |
helpers … | d2h … | vram peak …`, then `gpu chunked … opening re-encode …`)
and compare phase by phase against that log, not total against total.

**Record on every row:** `--threads`, `RAYON_NUM_THREADS`, the CPU model and
the logical-CPU count. Every archived 8B run used `--threads 8` on a
22-thread laptop; `results/cl1_floors.sh` defaults all three thread knobs to
**2** because this box is shared, and those defaults should be raised on a
dedicated machine — but then they are part of the row's identity.

---

### D.7 A digest that moves — stop, and collect this

A proof digest that differs on new hardware is **a bug, not a hardware
finding** (`BLACKWELL_5090_RUNBOOK.md:178-181`). Everything stops: no
timing is taken, no arm is re-run "to see", nothing is reported as a
measurement.

Collect, in one place under `$EV`:

1. the produced proof's **full** SHA-256 and exact byte count, taken by hand
   with `sha256sum` and `stat -c %s`, against the expectation from B.10;
2. the complete run log, including the `gpu: ON` line, any
   `[UPERF3-AJ] WARNING` line, and the `HASHLINE_TIMING` record;
3. both binaries' SHA-256, `git rev-parse HEAD`, `git status --short`;
4. the floors `manifest.json` (it already carries argv, timestamps, binary
   digests, both crates' tree ids and both lockfile hashes);
5. B.1's machine files plus driver, NVRTC and `cudarc` feature versions;
6. **the same gate run on the CPU binary on the same box.** If CPU and GPU
   agree on the new (wrong) digest, the divergence is in the source or the
   export copy; if they disagree, it is device codegen. That one extra run
   halves the search.

---

### D.8 Small operational traps, each of which has cost someone a run

* **The floors script refuses a dirty tree.** `results/cl1_floors.sh:252-253`
  aborts on *any* uncommitted change under `hashline/` or `zkp-core/`. The
  `cuda-12080` edit of B.4 must be **committed** first.
* **A hardcoded export path.** `hashline/src/export.rs:38-42` falls back to
  `/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl` when
  `M125_EXPORT_DIR` is unset. Either keep that exact path (recommended) or
  set the variable everywhere.
* **The suite version pins exact test counts.** `--suite-version 9` expects
  32 zkp-core tests and 227 storage-enabled hashline tests
  (`results/cl1_floors.sh:62-64`). If the branch under test has a different
  count, those cases go red while the twelve byte gates stay green — read
  the manifest, not the exit code, and use the version the orchestrator
  names.
* **`--out` must be a new directory** for `scripts/hashline_benchmark.py run`;
  it refuses to reuse one.
* **Disk.** Nothing here needs 200 GB, but it is worth knowing where it
  goes: the clone ~0.2 GB; build artifacts ~5.2 GB on this box
  (`hashline/target` 4.9 G + `target-gpu` 292 M); the cargo registry
  ~0.4 GB; the exports **7.0 GB**; each 8B proof **1.23 GB** (a 20-run
  campaign retains one) and the private one 1.29 GB; a weight cache 129 MB.
  Call it **40 GB** for everything on this page at once.

## E. What I could not determine

This page was written read-only, from this repository and this laptop. No
build, binary, proof or benchmark was run, and nothing was fetched from the
network.

**About the new machine, because it does not exist yet:**

* Its **system RAM, CPU model, PCIe generation and disk type** — all four
  change the first number (D.3, D.4, D.6). §A step 4 asks Victor for the
  RAM; the rest the agent reads in B.1.
* Whether **Ubuntu 24.04 LTS is still the right recommendation** at install
  time, and whether NVIDIA publishes a CUDA apt repository for whatever
  newer LTS exists by then. I could not check developer.nvidia.com. The
  reasoning behind 24.04 is stated in §A step 1 so it can be re-decided.
* **The exact CUDA 12.8 package name and layout on that distribution** —
  in particular whether the deb ships the versionless
  `lib64/libnvrtc-builtins.so.12.8` symlink that the project's preflight
  globs for (`scripts/hashline_cl_5090_preflight.py:180-190`). B.3 checks
  for it explicitly for that reason.
* Whether **`cargo build --locked` succeeds on a first networked build** of
  these 39 + 24 pinned packages. The lockfiles carry checksums and nothing
  in them looks unusual, but no build was run.

**About the code, where the repository itself does not say:**

* Whether `cudarc 0.13.9`'s **`cuda-12080` binding is safe against a 12.9+
  toolkit**. It is the crate's highest CUDA feature; I recommend installing
  **12.8 exactly** rather than finding out.
* Whether the two withdrawn bank-conflict kernels (`HL_GPU_SMEM_SWZ`,
  `HL_GPU_SMEM_SWZ_PB`) behave differently on **sm_120**. They were
  withdrawn on measurement on sm_89; that shared-memory conflict geometry is
  architecture-dependent is my inference, not the lane's claim.
* What the **repaired private construction costs at Mistral width** — the
  repository's own largest uncertainty. It is blocked on the `--mr1` entry
  point of `ZK60_PRIVATE_FFN_COST_PROBE.md` §5.1 tier 1, which is a code
  item and **not** unblocked by the new hardware (C.5).
* Whether **32 GB of video memory is enough for rung R5** (the repaired
  construction with the endpoint arguments on). §3.3 of the probe gives
  [MODEL] peaks for R0–R4 and none for R5.

**About the numbers on this page:**

* **No number in this repository has ever been taken on native Linux, or on
  any Blackwell part.** Every `[MODEL]` here inherits that, including the
  20–27 s of C.2.
* The 12 × 512 anchors in C.1 (2.07–2.24 s public, 5.25–5.67 s ZK) are taken
  from **byte-gate logs on this shared laptop**
  (`results/cl18_frozen_gates.log`, `results/floors_round16_an.log`), not
  from a quiesced measurement session. They are the right order of
  magnitude and the right ratio; they are not contract-grade, and this box
  has documented ~2× run-to-run variance.
* `ZK60_FIVE_SECOND_PLAN.md` §4.3's projection and §5's two corrections have
  **not been reconciled into a single revised number** by their authors.
  §4.3 says 20–27 s on the arithmetic of an 11.9 s host; §5's first
  correction says the host is 18–19 s and therefore "a bigger card alone
  buys less than §4.3 says", without publishing the re-run arithmetic. C.2
  quotes both and does not invent the reconciliation.
* The weight-cache arm (C.2 arm (c)) has an internal tension I could not
  resolve: the plan's step 2 expects **−6 s (range 3–9)**, while the
  58.40 s run's own weight-cache line reports `commit(miss) 17.028 s`
  (`results/hashline_convert_r3.log:541`), which is what a perfectly warm
  cache would have to remove from. The arm is cheap; it will settle itself.

**Operationally:**

* Victor's SSH key, the network arrangement and whether the new box is
  reachable from the laptop that holds the 7 GB of exports — the `rsync`
  lines in B.9 assume a direct route and are themselves inferred.

*(draft complete)*
