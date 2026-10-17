# Giving the WSL laptop SSH access to the Mac and the 5090 box

Written 2026-10-17 by Claude for Victor. The laptop's public key (safe to share;
the private key never leaves the laptop), fingerprint
`SHA256:lL3YCmqK4jpLCt005l2Kp+Xte4/CWn5jxvvo9tINNVU`:

```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGXj+sv06S121ml/e6b8phe0WPqOAdfLFsRXlbKSpHHLSQl8fAED2Z8caATBgnYZZ9T+ynONPaZd3mYnclF0r6rXl5FgQlQYBUkQXDGnvA1ZNIp6vAR1W0AeKZ8UdEEzfxvkn167cDhC6Kv6jYtELyACm29ix+1kSZN3Vem01uSzXJ0sbYzfNj1M0SqQjg4P4+/gCOvM6x3CPBtSM/DNacpPoAY43kK0FC3jT+Mgl9XRknXStxeSSrmQSwiauOJhYgHbN49GAYccnq9aJctRpLeVZcC/9hDHRY9bpbHAfDjXj3r+w86We2FWVNseoYSByirNFT5wHAnZt9BPuBrxy87A4t3ejlZiO3mF3BZGwbKNCvwbC7q127628bzw4eUN4NxgIWKbjx9K/EDFwAxCPelzyJhgLbjLejm/B6+OHjxT6/zkI1SwdqQZgICh6YFr/0RDrOLl3ot4IcfWc7igT4TwYc6y7k3FsfgknDsbYN/C0xQs7HDatqoXyALl/xxcM= victor@MSI
```

## Mac M3 Ultra (256 GB) — about one minute

**Victor, 2026-10-16 19:53 PDT (Telegram): the Mac will be reached through
Tailscale.** Then: install Tailscale on the Mac and sign in; on the laptop side
either run Tailscale inside WSL (`curl -fsSL https://tailscale.com/install.sh | sh`,
`sudo tailscale up`) or use the Windows Tailscale client with WSL mirrored
networking; Remote Login and the key below are still needed; tell Claude the
Mac's Tailscale name or 100.x address and user.

1. System Settings > General > Sharing > **Remote Login: On** (allow your user).
2. In Terminal on the Mac:
   ```
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGXj+sv06S121ml/e6b8phe0WPqOAdfLFsRXlbKSpHHLSQl8fAED2Z8caATBgnYZZ9T+ynONPaZd3mYnclF0r6rXl5FgQlQYBUkQXDGnvA1ZNIp6vAR1W0AeKZ8UdEEzfxvkn167cDhC6Kv6jYtELyACm29ix+1kSZN3Vem01uSzXJ0sbYzfNj1M0SqQjg4P4+/gCOvM6x3CPBtSM/DNacpPoAY43kK0FC3jT+Mgl9XRknXStxeSSrmQSwiauOJhYgHbN49GAYccnq9aJctRpLeVZcC/9hDHRY9bpbHAfDjXj3r+w86We2FWVNseoYSByirNFT5wHAnZt9BPuBrxy87A4t3ejlZiO3mF3BZGwbKNCvwbC7q127628bzw4eUN4NxgIWKbjx9K/EDFwAxCPelzyJhgLbjLejm/B6+OHjxT6/zkI1SwdqQZgICh6YFr/0RDrOLl3ot4IcfWc7igT4TwYc6y7k3FsfgknDsbYN/C0xQs7HDatqoXyALl/xxcM= victor@MSI' >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ipconfig getifaddr en0; whoami
   ```
3. Tell Claude `user@<the IP printed>` (WSL may not resolve `name.local`; the
   IP or a Tailscale name works).

First use (Claude, read-only before anything else): `uname -m`, `sw_vers`,
`sysctl hw.memsize hw.ncpu`, `xcode-select -p`, Rust toolchain presence. Then a
CPU-only build of `ops/zkp-mvp/trained-1b` (no `gpu-cuda`), its fast tests, and
only then 8B-scale CPU proofs under a Mac memory cap.

## RTX 5090 machine — after Ubuntu 24.04 is installed

Install media and steps: `docs/zkmatrix-poc/ZK60_HARDWARE_SETUP.md`. Then:
```
sudo apt install -y openssh-server
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGXj+sv06S121ml/e6b8phe0WPqOAdfLFsRXlbKSpHHLSQl8fAED2Z8caATBgnYZZ9T+ynONPaZd3mYnclF0r6rXl5FgQlQYBUkQXDGnvA1ZNIp6vAR1W0AeKZ8UdEEzfxvkn167cDhC6Kv6jYtELyACm29ix+1kSZN3Vem01uSzXJ0sbYzfNj1M0SqQjg4P4+/gCOvM6x3CPBtSM/DNacpPoAY43kK0FC3jT+Mgl9XRknXStxeSSrmQSwiauOJhYgHbN49GAYccnq9aJctRpLeVZcC/9hDHRY9bpbHAfDjXj3r+w86We2FWVNseoYSByirNFT5wHAnZt9BPuBrxy87A4t3ejlZiO3mF3BZGwbKNCvwbC7q127628bzw4eUN4NxgIWKbjx9K/EDFwAxCPelzyJhgLbjLejm/B6+OHjxT6/zkI1SwdqQZgICh6YFr/0RDrOLl3ot4IcfWc7igT4TwYc6y7k3FsfgknDsbYN/C0xQs7HDatqoXyALl/xxcM= victor@MSI' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
hostname -I; whoami
```
Claude does the NVIDIA driver/CUDA checks read-only first, then the guarded
GPU canary, then the TinyLlama stack and the 8B profile.
