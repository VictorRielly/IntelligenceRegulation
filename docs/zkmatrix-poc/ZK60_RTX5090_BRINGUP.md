# Bringing up the RTX 5090 desktop (Ubuntu 24.04 LTS)

Written 2026-11-06 for Victor. It covers making the USB stick on the Mac, installing Ubuntu on the desktop, and one
script that installs everything the project needs. A short project-side list comes at the end.

**The two scripts:**
- `scripts/rtx5090/make_ubuntu_usb_macos.sh` runs on the Mac. It downloads and verifies the image, refuses any disk
  that is not a USB stick, and writes the stick.
- `scripts/rtx5090/setup_ubuntu_2404.sh` runs on the desktop, once after installing and once more after a reboot with
  `--verify`.

Neither script has been run on the desktop yet: there is no Linux machine here to test on. The Mac script's safety
checks and image lookup were tested on the Mac, including its refusal of the internal disk. The setup script passes a
syntax check, and its generated environment file was tested.

## Why Ubuntu 24.04 LTS, the open NVIDIA driver and CUDA 12.9

- **Ubuntu 24.04 LTS:** the current image is 24.04.5.1 (releases.ubuntu.com, checked 2026-11-06). It is supported to
  2029, and NVIDIA publishes CUDA 12.8 and 12.9 for it. NVIDIA's Ubuntu 26.04 repository has no CUDA 12.x packages.
- **CUDA 12.x:** the prover's CUDA backend uses `cudarc` 0.13 with CUDA 12 bindings and compiles its kernels at run
  time with NVRTC. The code already knows the RTX 5090's architecture (`compute_120`), which needs CUDA 12.8 or newer.
  - CUDA 13 renames the NVRTC library, and `cudarc` 0.13 may not find it [INFERRED]. So 12.9, the last 12.x.
- **The driver:** RTX 50-series cards only work with NVIDIA's *open* kernel modules (driver branch 570 or newer).
  - The script installs the newest open branch from Ubuntu's own archive (580 or later). Ubuntu signs those modules,
    so Secure Boot can stay on.
  - It takes only the CUDA toolkit from NVIDIA's repository. It pins that repository so it can never replace the
    driver, because mixing the two breaks installs.

## 1. What you need

- A USB stick of 16 GB or more. **It will be erased.**
- The desktop, with a monitor plugged into the RTX 5090 (not the motherboard's own video output).
- A wired network for the install, if you can.
- **Where Linux will live:**
  - Best: a separate NVMe drive just for Linux.
  - Possible: dual-boot beside Windows, in free space you made in Windows first.
  - The installer's "Erase disk" wipes the drive you pick. If the desktop holds anything you want, back it up first.

## 2. Make the USB stick (on the Mac)

In Terminal on the Mac, from the repository:

```
scripts/rtx5090/make_ubuntu_usb_macos.sh --list
```

Plug in the stick and run `--list` again. Note the new disk's name (for example `disk4`) and check that its size
matches the stick. Then:

```
scripts/rtx5090/make_ubuntu_usb_macos.sh disk4
```

What happens:
- It downloads the newest Ubuntu 24.04 desktop image (about 6 GB) to `~/Downloads` and checks its SHA-256. If `gpg` is
  installed it also checks Ubuntu's signature.
- It refuses the disk if it is internal, not on USB, not removable or ejectable, or over 300 GB.
- It asks you to type the disk name again, then asks for your Mac password (for `dd`).
- Writing takes 5–15 minutes. Press Ctrl+T in that window to see progress. It ejects the stick at the end.

(If you prefer an app, balenaEtcher does the same job: choose the `.iso` in `~/Downloads`, then the stick.)

## 3. Firmware (BIOS/UEFI) settings on the desktop

Enter setup with Del or F2 at power-on, depending on the motherboard.

- **Boot mode:** UEFI, with CSM/Legacy off.
- **Secure Boot:** it can stay on.
- **For the RTX 5090:** turn on **Above 4G Decoding** and **Resizable BAR** if they are not already on.
- **If the USB stick does not show up:** turn off **Fast Boot**.
- Save and exit.

Then boot from the stick with the one-time boot menu: usually F12, F11, F8 or Esc, depending on the motherboard. Pick
the entry that says **UEFI:** and the stick's name.

## 4. Install Ubuntu

1. In the stick's menu, choose **Try or Install Ubuntu**.
   - If the screen goes black, reboot. In that menu, press `e`, add `nomodeset` after `quiet splash`, and press F10.
2. Choose **Install Ubuntu**, then **Interactive installation**, then **Default selection**.
3. Tick **"Install third-party software for graphics and Wi-Fi hardware"**. This installs the NVIDIA driver during
   the install.
   - With Secure Boot on, the installer may ask you to set a password. Remember it. At the first reboot a blue "MOK
     management" screen asks for it: choose **Enroll MOK**, then **Continue**, then enter the password.
4. **Disk:**
   - If Linux has its own drive, choose **Erase disk and install Ubuntu** and pick **that** drive. Check the drive's
     model and size.
   - For dual-boot, choose **Install alongside Windows**, or **Manual** with the free space.
5. **Your account:**
   - Use the username **`victor`**. The project's older scripts and docs use `/home/victor/...` paths, and those work
     again with this name.
   - Name the computer something like **`zk60-5090`**.
6. Finish, remove the stick when asked, and reboot.

## 5. Run the setup script (on the desktop)

Open **Terminal** (Ctrl+Alt+T) and run:

```
curl -fsSL https://raw.githubusercontent.com/VictorRielly/IntelligenceRegulation/main/scripts/rtx5090/setup_ubuntu_2404.sh -o setup.sh
bash setup.sh --git-name "Victor Rielly" --git-email "<the email you commit with>"
```

It asks for your password once (for `sudo`), and once for an SSH key passphrase. It takes 20–40 minutes, mostly
downloads. It is safe to run again if anything fails half way, and it logs to `~/zk60-setup.log`.

**What it installs:**
- **Base tools:** compilers (gcc, clang), git, cmake, Python 3 with numpy, tmux, htop, btop, nvtop, the SSH server,
  bubblewrap (the research explorer's sandbox) and monitoring tools.
- **The NVIDIA open driver:** the newest open branch at 570 or above from Ubuntu's archive, unless the installer already
  set it up.
- **The CUDA 12.9 toolkit:** nvcc and NVRTC, from NVIDIA's repository, with the driver pinned to Ubuntu's.
  `/etc/profile.d/zk60-cuda.sh` sets `CUDA_HOME`, `CUDA_ROOT`, `PATH` and `LD_LIBRARY_PATH`.
- **Toolchains:** Rust (rustup, stable), Lean (elan and `leanprover/lean4:v4.34.1`, the toolchain `formal/` pins) and
  uv for Python projects.
- **Agent CLIs:** Node.js 22, the Codex CLI (for Sol and Astra) and Claude Code.
- **Accounts and the repository:**
  - an SSH key for GitHub, with GitHub's host key checked against its published fingerprint;
  - the repository in `~/IntelligenceRegulation`, on the branch `perf/zk-batch-optimizations`;
  - Mathlib's prebuilt files for `formal/`.

**What it changes on the machine:**
- **Suspend and hibernate are disabled,** so a long proof is not interrupted. Use `--keep-sleep` to leave them on.
- **Kernel and NVIDIA driver updates wait for you.** An automatic driver update in the middle of a run breaks new GPU
  processes until a reboot. About once a month, between runs: `sudo apt full-upgrade && sudo reboot`. Use
  `--auto-kernel-updates` to keep automatic updates.
- **"Linger" is on for your user,** so the resource guard's detached jobs survive logging out.

**When it says REBOOT,** reboot (and enroll the MOK if the blue screen appears), then:

```
bash setup.sh --verify
```

It checks four things:
- `nvidia-smi` sees the RTX 5090 with compute capability 12.0;
- a small CUDA test kernel compiles for `sm_120` and gives the right answer;
- NVRTC is present, and every tool reports a version;
- the prover builds with its CUDA feature.

It ends with **ALL CHECKS PASSED**, or a list of what failed.

## 6. Three things only you can do

1. **GitHub key.**
   - The script prints a public key line starting `ssh-ed25519`. Add it at https://github.com/settings/keys (New SSH
     key).
   - Then `ssh -T git@github.com` should greet you by name. HTTPS tokens and the `gh` CLI are dead for this account;
     SSH works.
2. **Log in to the agents.**
   - Run `claude` and type `/login`. A browser opens.
   - Run `codex` and sign in.
3. **Bring the Mac's private settings across, never through the repository.** These files are not in git:
   - `.claude/settings.json` and `.claude/settings.local.json`, the permission allowlists. `settings.local.json` may hold
     the Telegram hook's token: it is private.
   - Claude's memory for this project, so the new box remembers what the Mac session knows.
   - From the Mac (the desktop's name answers on the local network as `zk60-5090.local`):

```
scp ~/IntelligenceRegulation/.claude/settings.json ~/IntelligenceRegulation/.claude/settings.local.json victor@zk60-5090.local:IntelligenceRegulation/.claude/
ssh victor@zk60-5090.local mkdir -p .claude/projects/-home-victor-IntelligenceRegulation/memory
scp -r ~/.claude/projects/-Users-victorrielly-IntelligenceRegulation/memory/ victor@zk60-5090.local:.claude/projects/-home-victor-IntelligenceRegulation/
```

Then tell the coordinator these facts, so the resource guard and the plans can be set for the machine:
- the machine's CPU, RAM and disk sizes;
- the output of `nvidia-smi`;
- the last lines of `bash setup.sh --verify`.

## 7. If something goes wrong

- **A black screen after installing:** at the boot menu (hold Shift, or press Esc), press `e`, add `nomodeset`, boot,
  and run the setup script. It installs the right driver.
- **`nvidia-smi` says no device:**
  - Check that the 5090's power connector (12V-2x6) is pushed fully home, and that the monitor cable is in the 5090.
  - Check that Secure Boot's MOK was enrolled: `mokutil --sb-state`, `dmesg | grep -i nvidia`.
- **"Driver/library version mismatch":** a driver update happened. Reboot.
- **The script stopped half way:** run the same command again. Every step skips what is already done. The log is
  `~/zk60-setup.log`.

## 8. The project side, after the box is up (for the coordinator and agents)

- **The resource guard.** Set it up for the new machine before any heavy run. `VRAM_CAP_MIB = 7400` was the RTX 4070's
  8 GB card; on the 5090 (32 GB) it needs its own measured cap. Check the RAM budget against MemTotal and confirm the
  cgroup caps work.
- **The CUDA backend has to catch up with the Metal work since 2026-10-31.** Much of the efficiency plan's device work
  was written for Metal: A4's weight products, A12's slot tables, A7's queues and others. Each needs its CUDA form,
  each with the same byte gates:
  - the W16R2 rung golden `96e4f0b6`, CPU = CUDA;
  - the six digests;
  - the 8B core `90003b760eb7ad80`;
  - receipts 818,728,672 B.
  This is a lane of its own.
- **Then the timing ladders** on a quiet box, against D64's target of at least 110 proved tokens/s.
- **What stayed on the old laptop does not come back:** 446 GiB of large files and the owner-private keys, salts and
  openings (`SNAPSHOT_20261017_EXCLUDED_LARGE_FILES.json`). Anything needed is re-fetched or regenerated.

Sources: Ubuntu releases (https://releases.ubuntu.com/24.04/); NVIDIA's CUDA repository for Ubuntu 24.04
(https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/); the open-module requirement for the RTX
50 series and the 580 branch on Ubuntu (https://ubuntuhandbook.org/index.php/2025/09/ubuntu-added-nvidia-580-driver/,
https://forums.developer.nvidia.com/t/rtx5090-driver-installation-on-ubuntu-24/347108); CUDA versions per Ubuntu
release (https://linuxcapable.com/how-to-install-cuda-on-ubuntu-linux/); GitHub's SSH host key fingerprints
(docs.github.com, checked against `ssh-keyscan` on 2026-11-06).
