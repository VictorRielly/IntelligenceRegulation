# Linux RTX 5090 and M3 Ultra setup

**Status 2026-10-17 (Victor, in session):** the Mac M3 Ultra has **256 GB**
unified memory (correcting the 512 GB written below on 2026-09-27) and is not
yet reachable from the WSL laptop (Remote Login/SSH to be enabled); the RTX 5090
machine still has **no Linux installed**. Neither machine has been inspected.

Victor confirms both machines are available; the RTX 5090 will run Linux.
**Latest clarification:** the 5090 machine has no Linux installation yet.
Create installation media first; there is no existing Linux/SSH host to inspect.
Use the 5090 for the current CUDA proof backend and throughput experiments.
Use the M3 Ultra's 256 GB unified memory for large CPU reference/witness
work and memory-heavy correctness experiments. A Metal proof backend does
not exist in this repository; it would be a separate implementation project.
The Mac's memory does not extend the separate 5090's VRAM.

NVIDIA specifies 32 GB GDDR7 for the RTX 5090. Its inference performance does
not predict proof throughput. [NVIDIA specifications](https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/rtx-5090/).
Apple documented M3 Ultra configurations up to 512 GB at launch; Victor's
machine has 256 GB (stated 2026-10-17). [Apple launch specifications](https://www.apple.com/newsroom/2025/03/apple-unveils-new-mac-studio-the-most-powerful-mac-ever/).

## Fresh Linux installation on the 5090 PC

Use **Ubuntu 24.04 LTS Desktop, 64-bit PC (AMD64)** for this bring-up. It is
a supported CUDA distribution and fits the repository's current CUDA 12.x
development baseline. The official release page currently offers 24.04.5.1.
AMD64 is the PC image for both Intel and AMD x86-64 CPUs.
[Ubuntu image](https://releases.ubuntu.com/24.04/),
[NVIDIA distribution support](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/).

1. On the M3 Ultra, download the Ubuntu PC ISO and
   [balenaEtcher for macOS arm64](https://etcher.balena.io/).
2. Insert a spare **16 GB or larger USB stick**. In Etcher, select the ISO,
   select that USB stick, then flash and validate. Flashing erases the USB.
3. Move the USB to the 5090 PC and boot its UEFI USB entry using the
   motherboard's boot menu. The Mac is only preparing the installer.
4. Choose Install Ubuntu and the intended internal SSD. Select the erase-disk
   option only for a disk whose existing contents can be deleted. Check the
   model/capacity in the install summary before confirming.
5. Complete installation, remove the USB when prompted, and reboot.

[Ubuntu's USB instructions](https://ubuntu.com/desktop/docs/en/latest/how-to/create-a-bootable-usb-stick/)
and [installation walkthrough](https://ubuntu.com/tutorials/install-ubuntu-desktop)
show the screens. Creating the USB and installing onto the internal SSD are
separate steps; copying the ISO file onto the SSD is not an installed OS.

After the desktop starts, install Ubuntu updates, then use **Software &
Updates → Additional Drivers** to select the recommended NVIDIA driver
supporting this GPU and reboot. Follow any Secure Boot key-enrollment prompts.
Confirm `nvidia-smi` identifies the RTX 5090 before installing the project
toolchain. [Ubuntu NVIDIA driver guide](https://ubuntu.com/desktop/docs/en/latest/how-to/graphics/install-nvidia-drivers/).
The CUDA toolkit/NVRTC installation follows driver validation, using the
versioned NVIDIA package repository instructions for the installed OS.

## Inventory after the OS is installed

Copy `scripts/zk60_host_preflight.py` to the machine, then run:

```sh
python3 zk60_host_preflight.py
```

It only reports OS, architecture, RAM, disk space, tool versions and, on
Linux, GPU/driver/NVRTC capability. It installs nothing, uses no network,
loads no model, and records no host name, machine serial or credentials.
NVRTC is queried through its version/architecture APIs without compiling or
launching a kernel. The output is an environment inventory, not a passing
GPU or proof gate. Share that text or provide an existing SSH connection
alias when the machines are reachable; keys/passwords need not enter chat.

If Python is not installed, start with these read-only Linux commands:

```sh
cat /etc/os-release
nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv
free -h
df -h .
```

On the Mac, the initial read-only commands are:

```sh
sw_vers
uname -m
sysctl -n hw.memsize
xcode-select -p
```

## Linux 5090 bring-up

1. Inspect the newly installed distribution/version and driver before
   choosing CUDA/toolchain package commands.
2. Install a supported NVIDIA driver and a toolkit whose **NVRTC supports
   `compute_120`**. NVIDIA added Blackwell compiler support in CUDA 12.8;
   check the actual loaded NVRTC library rather than trusting `nvcc --version`
   or nvidia-smi's advertised CUDA version. The repository already has a
   compute_120 branch and logs a warning if it falls back to generic PTX.
   [NVIDIA CUDA 12.8 release notes](https://docs.nvidia.com/cuda/archive/12.8.0/cuda-toolkit-release-notes/).
3. Install/verify the Rust toolchain, C/C++ build tools, Python and CMake;
   use the repository lockfiles. Record versions and source hashes.
4. Copy a reviewed source snapshot including isolated candidate changes.
   Cloning main alone currently omits the new shaped/fusion/keyed-GPU work.
   Resolve dependencies once, then use locked offline builds for evidence runs.
5. Run CPU field/encoding/proof gates, then small required-device CUDA gates.
   Require native architecture compilation and actual device dispatch;
   a skipped GPU test or successful CPU fallback does not qualify.
6. Increase the workload only after correctness and memory checks. Record
   host RAM, VRAM, transfers, witness time, complete proof readiness, separate
   verification and cold/warm timings. Start with chunked commitments and a
   bounded development shape before a trained full-model proof.

The CPU host also retains witnesses, commitment data and helper tables; 32 GB
VRAM alone does not establish that the complete profile fits. The
[allocation-free layout audit](../../results/zk60_sol_model_20260927/layout-readiness.md)
counts a **25.70 GiB retained payload floor at 512 tokens** and **70.57 GiB at
1,024 tokens** for the historical 7.24B Mistral geometry. These are computed
counts for an unregistered shape, not measured peak memory or an admitted
8B profile. They exclude weights and some simultaneous scratch allocations.
The frozen baseline keeps encoded commitments in host RAM. The separately
validated keyed GPU candidate's chunked route already streams those
codewords and recomputes queried columns. Its
[new memory audit](../../results/zk60_sol_model_20260927/gpu-chunked-memory-audit.md)
counts A/H alone retaining about 5.18/14.23 GiB on the host and 5.17/14.22 GiB
in VRAM at T512/T1024. These are separate memory tiers, not additive VRAM.
During H construction, host A/H data plus witness/lookup collections alone
reach at least 9.86/27.17 GiB. All exclude further live scratch and runtime
overhead. The earlier materialized floors therefore do not describe a
successful chunked device run; CPU fallback would reintroduce them. The
5090 host's system RAM and measured peaks are still needed to select a
feasible schedule. Longer context increases attention work quadratically.

## M3 Ultra bring-up

Check native `arm64` tools, macOS version and command-line developer tools,
then build the portable CPU core without `gpu-cuda`. Run its exact field,
NTT, commitment and proof differential checks before using the machine for
large witnesses. Transfer synthetic/public validation inputs first. Keep
actual private witness tensors and rejected proof attempts out of public
reports. Host capacity and CPU speed will be measured on the Mac itself.

The first deployment milestone is two working, source-pinned environments:
Linux CUDA proving on the 5090, CPU reference/witness work on the Mac.
Neither setup alone establishes the >=50 proved-token/s private 8B target.

The [Mac source audit](../../results/zk60_sol_fusion_20260927/mac-portability.md)
finds no explicit x86-only CPU code and resolves the arm64 dependency graph;
it does not establish a Mac build. It identifies required public metadata
fixtures, Linux-specific export defaults and missing macOS memory telemetry.
The portable development snapshot includes those metadata fixtures plus the
historical toy receipt/policy required by compatibility testing. Large ignored
tests need a working memory guard before use on the Mac.

A separate [Mac peak-memory repair](../../results/zk60_sol_macmem_20260927/README.md)
now supplies macOS peak RSS and makes the 12-block test reject unavailable
telemetry before building its witness chain. Linux compilation and three
targeted tests pass; root checked its source pins and patch applicability.
It remains separate from the frozen CUDA snapshot and still needs a native
Mac build and a live telemetry check. Current RSS is unavailable on Mac;
peak RSS is host-process memory, not a GPU allocation measurement.
