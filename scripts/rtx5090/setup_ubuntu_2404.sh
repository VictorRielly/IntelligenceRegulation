#!/usr/bin/env bash
# zk60: set up a FRESH Ubuntu 24.04 LTS desktop with an RTX 5090 for the IntelligenceRegulation project.
# Guide: docs/zkmatrix-poc/ZK60_RTX5090_BRINGUP.md
#
# Run as your normal user (not root), from a terminal on the desktop, with the internet connected:
#   bash setup_ubuntu_2404.sh [options]         # first run: everything; reboot when it says so
#   bash setup_ubuntu_2404.sh --verify          # after the reboot: GPU, CUDA, compilers, a test kernel, the prover build
#
# Options:
#   --git-name "Name" --git-email "addr"   set git's identity (otherwise left as it is)
#   --no-driver        do not install the NVIDIA driver (already installed by the Ubuntu installer, or you want your own)
#   --no-cuda          skip the CUDA toolkit
#   --no-agents        skip Node.js, the Codex CLI and Claude Code
#   --no-lean          skip elan / Lean
#   --no-repo          do not clone the repository
#   --keep-sleep       leave suspend/hibernate enabled (default: disabled, so long proofs are not interrupted)
#   --auto-kernel-updates  let unattended-upgrades update the kernel and NVIDIA driver (default: those wait for you)
#   --cuda 12-9        the CUDA toolkit series (default 12-9; the prover's cudarc bindings are CUDA 12)
#
# It is safe to run again: every step checks what is already there. A log goes to ~/zk60-setup.log.
# Nothing secret is written: no keys are uploaded anywhere; the SSH key it makes stays on this machine and you add its
# PUBLIC half to GitHub yourself.
set -euo pipefail

REPO_HTTPS="https://github.com/VictorRielly/IntelligenceRegulation.git"
REPO_SSH="git@github.com:VictorRielly/IntelligenceRegulation.git"
REPO_DIR="${HOME}/IntelligenceRegulation"
REPO_BRANCH="perf/zk-batch-optimizations"
LEAN_TOOLCHAIN="leanprover/lean4:v4.34.1"
NODE_MAJOR=22
# GitHub's published SSH host key fingerprint (docs.github.com, "GitHub's SSH key fingerprints")
GITHUB_ED25519_FPR="SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU"

CUDA_SERIES="12-9"
DO_DRIVER=1 DO_CUDA=1 DO_AGENTS=1 DO_LEAN=1 DO_REPO=1 KEEP_SLEEP=0 AUTO_KERNEL=0 VERIFY_ONLY=0
GIT_NAME="" GIT_EMAIL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --git-name) GIT_NAME="$2"; shift 2 ;;
    --git-email) GIT_EMAIL="$2"; shift 2 ;;
    --no-driver) DO_DRIVER=0; shift ;;
    --no-cuda) DO_CUDA=0; shift ;;
    --no-agents) DO_AGENTS=0; shift ;;
    --no-lean) DO_LEAN=0; shift ;;
    --no-repo) DO_REPO=0; shift ;;
    --keep-sleep) KEEP_SLEEP=1; shift ;;
    --auto-kernel-updates) AUTO_KERNEL=1; shift ;;
    --cuda) CUDA_SERIES="$2"; shift 2 ;;
    --verify) VERIFY_ONLY=1; shift ;;
    -h | --help) sed -n 2,24p "$0"; exit 0 ;;
    *) echo "unknown option $1 (see --help)" >&2; exit 2 ;;
  esac
done
CUDA_DOT="${CUDA_SERIES/-/.}"
CUDA_HOME_DIR="/usr/local/cuda-${CUDA_DOT}"

LOG="${HOME}/zk60-setup.log"
exec > >(tee -a "$LOG") 2>&1
REBOOT_NEEDED=0
NOTES=()
say() { printf '\n==> %s\n' "$*"; }
note() { NOTES+=("$*"); echo "NOTE: $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
have() { command -v "$1" > /dev/null 2>&1; }
apt_install() { sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"; }

preflight() {
  [ "$(id -u)" -ne 0 ] || die "run as your normal user, not root (the script uses sudo where it must)"
  [ "$(uname -m)" = "x86_64" ] || die "expected an x86_64 machine, got $(uname -m)"
  . /etc/os-release
  if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
    die "this script is written for Ubuntu 24.04 LTS (found ${PRETTY_NAME:-unknown})"
  fi
  say "zk60 setup on $(hostname), ${PRETTY_NAME}, kernel $(uname -r), $(date -u +%FT%TZ)"
  sudo -v
  # keep sudo alive while the script runs
  (while true; do sudo -n true; sleep 50; kill -0 "$$" 2> /dev/null || exit; done) 2> /dev/null &
  curl -fsS --max-time 10 https://github.com > /dev/null || die "no internet connection (github.com unreachable)"
}

base_packages() {
  say "Base packages"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
  apt_install software-properties-common
  sudo add-apt-repository -y universe > /dev/null
  sudo apt-get update
  apt_install \
    build-essential pkg-config git git-lfs curl wget ca-certificates gnupg cmake ninja-build clang lld \
    libssl-dev python3 python3-venv python3-pip python3-dev python3-numpy pipx jq htop btop nvtop tmux rsync \
    zstd unzip xz-utils openssh-server bubblewrap sysstat lm-sensors smartmontools numactl mokutil \
    ubuntu-drivers-common "linux-headers-$(uname -r)"
  sudo systemctl enable --now ssh
}

nvidia_driver() {
  if [ "$DO_DRIVER" -eq 0 ]; then say "NVIDIA driver: skipped (--no-driver)"; return; fi
  say "NVIDIA driver (open kernel modules: required for the RTX 50 series)"
  if have nvidia-smi && nvidia-smi > /dev/null 2>&1; then
    echo "already working: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader)"
    return
  fi
  if dpkg -l 'nvidia-driver-*' 2> /dev/null | grep -q '^ii'; then
    note "an NVIDIA driver package is installed but not loaded yet: reboot, then run with --verify"
    REBOOT_NEEDED=1
    return
  fi
  local list ver
  list=$(sudo ubuntu-drivers list 2> /dev/null || true)
  echo "$list"
  ver=$(echo "$list" | grep -oE 'nvidia-driver-[0-9]+-open' | sed -E 's/nvidia-driver-([0-9]+)-open/\1/' | sort -n | tail -1 || true)
  if [ -z "$ver" ]; then
    ver=$(apt-cache search --names-only '^nvidia-driver-[0-9]+-open$' | grep -oE 'nvidia-driver-[0-9]+' | grep -oE '[0-9]+$' | sort -n | tail -1 || true)
  fi
  [ -n "$ver" ] || die "no nvidia-driver-*-open package found (is the GPU seated and the 'restricted' component enabled?)"
  [ "$ver" -ge 570 ] || die "newest open driver is $ver; the RTX 5090 needs 570 or newer"
  echo "installing the open driver branch $ver from Ubuntu's archive (signed modules: Secure Boot keeps working)"
  if ! sudo ubuntu-drivers install "nvidia:${ver}-open"; then
    echo "ubuntu-drivers could not install nvidia:${ver}-open; installing the packages directly"
    apt_install "nvidia-driver-${ver}-open"
    local flavour="generic-hwe-24.04"
    apt-cache show "linux-modules-nvidia-${ver}-open-${flavour}" > /dev/null 2>&1 || flavour="generic"
    apt_install "linux-modules-nvidia-${ver}-open-${flavour}" || note "precompiled modules not found; the DKMS build will be used (with Secure Boot on, you will be asked to enroll a key (MOK) at the next boot)"
  fi
  if mokutil --sb-state 2> /dev/null | grep -qi enabled; then
    note "Secure Boot is ON. If a blue 'MOK management' screen appears at reboot, choose Enroll MOK and enter the password you set"
  fi
  REBOOT_NEEDED=1
}

cuda_toolkit() {
  if [ "$DO_CUDA" -eq 0 ]; then say "CUDA toolkit: skipped (--no-cuda)"; return; fi
  say "CUDA toolkit ${CUDA_DOT} (toolkit only; the driver stays Ubuntu's)"
  if [ ! -x "${CUDA_HOME_DIR}/bin/nvcc" ]; then
    if ! dpkg -l cuda-keyring 2> /dev/null | grep -q '^ii'; then
      wget -q -O /tmp/cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
      sudo dpkg -i /tmp/cuda-keyring.deb
    fi
    # Never take driver packages from NVIDIA's repository: mixing them with Ubuntu's driver breaks the install.
    sudo tee /etc/apt/preferences.d/zk60-no-driver-from-nvidia-repo > /dev/null << 'EOF'
Package: nvidia-driver-* nvidia-dkms-* nvidia-kernel-* nvidia-open* cuda-drivers* libnvidia-* xserver-xorg-video-nvidia-* nvidia-utils-* nvidia-compute-utils-* nvidia-firmware-*
Pin: origin developer.download.nvidia.com
Pin-Priority: -1
EOF
    sudo apt-get update
    if ! apt_install "cuda-toolkit-${CUDA_SERIES}"; then
      echo "the full toolkit did not install; installing the parts the prover needs"
      apt_install "cuda-nvcc-${CUDA_SERIES}" "cuda-nvrtc-${CUDA_SERIES}" "cuda-nvrtc-dev-${CUDA_SERIES}" \
        "cuda-cudart-dev-${CUDA_SERIES}" "cuda-nvml-dev-${CUDA_SERIES}" "cuda-command-line-tools-${CUDA_SERIES}"
    fi
  else
    echo "already installed: ${CUDA_HOME_DIR}"
  fi
  sudo tee /etc/profile.d/zk60-cuda.sh > /dev/null << EOF
# zk60: CUDA ${CUDA_DOT} (hashline's gpu-cuda feature reads CUDA_ROOT; cudarc loads libnvrtc from here)
export CUDA_HOME=${CUDA_HOME_DIR}
export CUDA_PATH=${CUDA_HOME_DIR}
export CUDA_ROOT=${CUDA_HOME_DIR}
case ":\$PATH:" in *":${CUDA_HOME_DIR}/bin:"*) ;; *) export PATH="${CUDA_HOME_DIR}/bin:\$PATH" ;; esac
case ":\${LD_LIBRARY_PATH:-}:" in *":${CUDA_HOME_DIR}/lib64:"*) ;; *) export LD_LIBRARY_PATH="${CUDA_HOME_DIR}/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}" ;; esac
EOF
  grep -q 'zk60-cuda.sh' "${HOME}/.bashrc" || echo '[ -f /etc/profile.d/zk60-cuda.sh ] && . /etc/profile.d/zk60-cuda.sh' >> "${HOME}/.bashrc"
}

rust_toolchain() {
  say "Rust (rustup, stable)"
  if [ ! -x "${HOME}/.cargo/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable -c clippy -c rustfmt
  else
    "${HOME}/.cargo/bin/rustup" update stable
  fi
  "${HOME}/.cargo/bin/rustc" --version
}

lean_toolchain() {
  if [ "$DO_LEAN" -eq 0 ]; then say "Lean: skipped (--no-lean)"; return; fi
  say "Lean (elan, ${LEAN_TOOLCHAIN})"
  if [ ! -x "${HOME}/.elan/bin/elan" ]; then
    curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
  fi
  "${HOME}/.elan/bin/elan" toolchain install "${LEAN_TOOLCHAIN}"
}

python_tools() {
  say "Python tools (uv)"
  if [ ! -x "${HOME}/.local/bin/uv" ]; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  "${HOME}/.local/bin/uv" --version || true
}

agent_tools() {
  if [ "$DO_AGENTS" -eq 0 ]; then say "Agent CLIs: skipped (--no-agents)"; return; fi
  say "Node.js ${NODE_MAJOR}, the Codex CLI and Claude Code"
  if ! have node || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt "$NODE_MAJOR" ]; then
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
    apt_install nodejs
  fi
  mkdir -p "${HOME}/.npm-global"
  npm config set prefix "${HOME}/.npm-global"
  grep -q '.npm-global/bin' "${HOME}/.bashrc" || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "${HOME}/.bashrc"
  export PATH="${HOME}/.npm-global/bin:${PATH}"
  npm install -g @openai/codex
  if [ ! -x "${HOME}/.local/bin/claude" ]; then curl -fsSL https://claude.ai/install.sh | bash; fi
  grep -q '.local/bin' "${HOME}/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
  note "log in once in a terminal: run 'claude' (then /login) and 'codex' (sign in) - both open a browser"
}

ssh_and_git() {
  say "SSH key and git"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  if [ ! -f "${HOME}/.ssh/id_ed25519" ]; then
    echo "Making an SSH key for GitHub. Choose a passphrase (recommended; the desktop keyring unlocks it at login),"
    echo "or press Enter twice for none."
    ssh-keygen -t ed25519 -f "${HOME}/.ssh/id_ed25519" -C "zk60-5090-$(hostname)"
  fi
  if ! grep -q '^github.com ssh-ed25519' "${HOME}/.ssh/known_hosts" 2> /dev/null; then
    ssh-keyscan -t ed25519 github.com 2> /dev/null > /tmp/zk60-gh-hostkey || true
    local fpr
    fpr=$(ssh-keygen -lf /tmp/zk60-gh-hostkey 2> /dev/null | awk '{print $2}' || true)
    if [ "$fpr" = "$GITHUB_ED25519_FPR" ]; then
      cat /tmp/zk60-gh-hostkey >> "${HOME}/.ssh/known_hosts"
      echo "GitHub host key verified ($fpr)"
    else
      note "GitHub's host key fingerprint did not match the published one ($fpr); NOT trusting it. Check your network"
    fi
  fi
  [ -n "$GIT_NAME" ] && git config --global user.name "$GIT_NAME"
  [ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"
  git config --global init.defaultBranch main
  git config --global pull.ff only
  note "add this PUBLIC key at https://github.com/settings/keys (New SSH key), then 'ssh -T git@github.com' should greet you:"
  note "$(cat "${HOME}/.ssh/id_ed25519.pub")"
}

clone_repo() {
  if [ "$DO_REPO" -eq 0 ]; then say "Repository: skipped (--no-repo)"; return; fi
  say "The repository (${REPO_DIR}, branch ${REPO_BRANCH})"
  if [ ! -d "${REPO_DIR}/.git" ]; then
    git clone "$REPO_HTTPS" "$REPO_DIR"
  fi
  git -C "$REPO_DIR" remote set-url origin "$REPO_SSH"
  git -C "$REPO_DIR" fetch --quiet "$REPO_HTTPS" "+refs/heads/*:refs/remotes/origin/*" || true
  # switch to the work branch only if we are not on it already; never reset a branch that exists (a re-run keeps
  # any local commits)
  local cur
  cur=$(git -C "$REPO_DIR" symbolic-ref --short -q HEAD || true)
  if [ "$cur" != "$REPO_BRANCH" ]; then
    if git -C "$REPO_DIR" rev-parse --verify --quiet "refs/heads/${REPO_BRANCH}" > /dev/null; then
      git -C "$REPO_DIR" checkout "$REPO_BRANCH"
    elif git -C "$REPO_DIR" rev-parse --verify --quiet "origin/${REPO_BRANCH}" > /dev/null; then
      git -C "$REPO_DIR" checkout -b "$REPO_BRANCH" --track "origin/${REPO_BRANCH}"
    fi
  fi
  git -C "$REPO_DIR" log --oneline -1
  if [ "$DO_LEAN" -eq 1 ] && [ -f "${REPO_DIR}/formal/lakefile.toml" ]; then
    say "Mathlib's prebuilt files for formal/ (a few GB)"
    (cd "${REPO_DIR}/formal" && "${HOME}/.elan/bin/lake" exe cache get) || note "lake cache get failed; run it again later: cd ~/IntelligenceRegulation/formal && lake exe cache get"
  fi
}

machine_settings() {
  say "Machine settings for long unattended runs"
  # the resource guard caps each job in a systemd --user cgroup; detached jobs need the user manager to outlive logins
  sudo loginctl enable-linger "$USER"
  if [ "$(stat -fc %T /sys/fs/cgroup)" != "cgroup2fs" ]; then note "cgroup v2 is not mounted; the resource guard's memory caps will not work"; fi
  local uc="/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers"
  if [ -r "$uc" ] && ! grep -qw memory "$uc"; then note "the memory controller is not delegated to your user manager; the guard will run without kernel caps"; fi
  if [ "$KEEP_SLEEP" -eq 0 ]; then
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target > /dev/null
    if have gsettings && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
      gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || true
      gsettings set org.gnome.desktop.session idle-delay 0 || true
    fi
    echo "suspend and hibernate disabled (undo: sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target)"
  fi
  if [ "$AUTO_KERNEL" -eq 0 ]; then
    # An automatic driver or kernel update in the middle of a run breaks new GPU processes until a reboot
    # ("driver/library version mismatch"). Those wait for a manual 'sudo apt full-upgrade && sudo reboot'.
    sudo tee /etc/apt/apt.conf.d/51zk60-hold-gpu-and-kernel > /dev/null << 'EOF'
Unattended-Upgrade::Package-Blacklist {
    "nvidia-";
    "libnvidia-";
    "linux-modules-nvidia-";
    "linux-image-";
    "linux-headers-";
    "linux-modules-";
    "linux-generic";
    "linux-hwe-";
    "cuda-";
};
EOF
    note "kernel and NVIDIA updates now wait for you: about once a month, between runs, 'sudo apt full-upgrade && sudo reboot'"
  fi
}

verify() {
  say "Verify"
  [ -f /etc/profile.d/zk60-cuda.sh ] && . /etc/profile.d/zk60-cuda.sh
  export PATH="${HOME}/.cargo/bin:${HOME}/.elan/bin:${HOME}/.local/bin:${HOME}/.npm-global/bin:${PATH}"
  local ok=1
  if nvidia-smi --query-gpu=name,driver_version,compute_cap,memory.total --format=csv,noheader; then
    nvidia-smi --query-gpu=compute_cap --format=csv,noheader | grep -q '^12\.0' || { echo "expected compute capability 12.0 (RTX 5090)"; ok=0; }
  else
    echo "nvidia-smi failed: the driver is not loaded (reboot? Secure Boot MOK?)"; ok=0
  fi
  if have nvcc; then
    nvcc --version | tail -2
    local t; t=$(mktemp -d)
    cat > "$t/add.cu" << 'EOF'
#include <cstdio>
__global__ void add(const int *a, const int *b, int *c, int n) { int i = blockIdx.x * blockDim.x + threadIdx.x; if (i < n) c[i] = a[i] + b[i]; }
int main() {
  const int n = 1 << 20; int *a, *b, *c;
  cudaMallocManaged(&a, n * sizeof(int)); cudaMallocManaged(&b, n * sizeof(int)); cudaMallocManaged(&c, n * sizeof(int));
  for (int i = 0; i < n; i++) { a[i] = i; b[i] = 2 * i; }
  add<<<(n + 255) / 256, 256>>>(a, b, c, n);
  cudaError_t e = cudaDeviceSynchronize();
  if (e != cudaSuccess) { printf("CUDA error: %s\n", cudaGetErrorString(e)); return 1; }
  for (int i = 0; i < n; i++) if (c[i] != 3 * i) { printf("wrong at %d\n", i); return 1; }
  printf("CUDA test kernel OK on sm_120\n"); return 0;
}
EOF
    if nvcc -arch=sm_120 -o "$t/add" "$t/add.cu" && "$t/add"; then :; else ok=0; fi
    rm -rf "$t"
    ls "${CUDA_HOME_DIR}"/lib64/libnvrtc.so* > /dev/null 2>&1 && echo "NVRTC present" || { echo "libnvrtc missing under ${CUDA_HOME_DIR}/lib64"; ok=0; }
  else
    echo "nvcc not found"; ok=0
  fi
  for c in rustc cargo lake node codex claude uv python3; do
    if have "$c"; then printf '%-8s %s\n' "$c" "$($c --version 2> /dev/null | head -1)"; else printf '%-8s MISSING\n' "$c"; fi
  done
  if [ -d "${REPO_DIR}/ops/zkp-mvp/gpu-metal/hashline" ]; then
    say "Building the prover with CUDA (hashline --features gpu-cuda; a few minutes)"
    if cargo build --release --locked --features gpu-cuda --manifest-path "${REPO_DIR}/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" --lib; then
      echo "hashline gpu-cuda build OK"
    else
      echo "hashline gpu-cuda build FAILED (send the output above to the coordinator)"; ok=0
    fi
  fi
  if [ "$ok" -eq 1 ]; then say "ALL CHECKS PASSED: the box is ready for the zk60 bring-up"; else say "SOME CHECKS FAILED (see above; the log is ${LOG})"; fi
}

preflight
if [ "$VERIFY_ONLY" -eq 1 ]; then verify; exit 0; fi
base_packages
nvidia_driver
cuda_toolkit
rust_toolchain
lean_toolchain
python_tools
agent_tools
ssh_and_git
clone_repo
machine_settings

say "Summary"
for n in "${NOTES[@]}"; do echo " - $n"; done
if [ "$REBOOT_NEEDED" -eq 1 ]; then
  say "REBOOT NOW (sudo reboot), then run: bash $0 --verify"
else
  verify
fi
