# Audit snapshot

## Git boundary

- Date: 2026-07-10, America/Los_Angeles
- Branch: `perf/zk-batch-optimizations`
- HEAD: `444f05792e35b3de2980ddc9ebac74def6d1f2f9`
- Prior audited base: `9fea0a5620679aa484dce3edaff9deae65b0def8`
- Delta: 25 files changed, 8,450 insertions, 246 deletions
- Implementation worktree at review start: clean
- Existing untracked content: `codex-audit-2026-07-09/`

The existing prior-audit folder belongs to the earlier review and was not
modified. This follow-up audit adds only `codex-audit-2026-07-10/`.

## Relevant commit sequence

```text
cf02fa8 R1 engine tranche
fc3794e R1 battery extended to all quadratic families
b0e1f75 E2 slot constancy
b1533f1 GF(q^16) scalar layer
753e988 sumcheck core
45ad224 fractional GKR
58957c4 SiLU fusion/table
29df666 E4 commitment claims
728ddd1 lookup ZK design round (design/spike only)
ef01e4d E4 hash-edge regressions
0928b41 M5 wide-object chunking
097475d M5 FFN-shape commitment measurements
444f057 lookup benchmark
```

## Key file hashes

```text
dbd3ff6b836dd2753c0ec0c2f096137a6adebe83177dd17bebed0f2c00d0487d  zkmatrix-rs/src/ring/ct_engine.rs
b34a1431fb6c945ca7c1bccfd30c6fd9ce73660fefa29c1f1e8ea729f819a26b  zkmatrix-rs/src/ring/link.rs
aa094937afa26de57dca8d3349b5fe31ad5c3dda7a664b978115ae647b262a2a  zkmatrix-rs/src/ring/kfield.rs
5ca856a32f7ff1998bf6e92f17fae1ab3c781f54957cc7c6beb2f6cd7d3dd1ea  zkmatrix-rs/src/ring/sumcheck.rs
5c49ecdf04a40844ee6dce16ca5811662ce626347d044b0178ec3596ad1422ec  zkmatrix-rs/src/ring/gkr.rs
6fd806600b79bc47adbbcd8be2c24412b23cc35aa99e96faf991a344720ba72f  zkmatrix-rs/src/ring/lookup.rs
8acebbf41f3ace38d354acf2d9261b2d89246c883dda56975fbaa75101a39c6e  zkmatrix-rs/src/ring/commit.rs
7c4e2d3806e8f87ec6d5441645034a22bc7ffd26b19eed92d43437548ca6cad0  zkmatrix-rs/src/bin/ring_matmul.rs
afd6c3680992a1979ebf7f6b815f5fac032c542f0add6bece34aaec70e7daf4f  docs/zkmatrix-poc/M4_LOOKUP_DESIGN.md
18461d81a0be3b2df65dfa3be629589101d82853e5cc99565311d0f2d8ec2d37  docs/zkmatrix-poc/M4_LOOKUP_ZK_DESIGN.md
fc9d370702256de8deddbd4d65f5cceb4ae025599d7f59d6ce4123d46823415e  docs/zkmatrix-poc/M5_LITE_REPORT.md
089666ab0476e0492a6fb010421b3265ea2ab0f60c815ce511d427b84fb8a0cd  docs/zkmatrix-poc/LLM_SCALE_ESTIMATE.md
```

## Environment

```text
rustc 1.96.0 (ac68faa20 2026-05-25)
cargo 1.96.0 (30a34c682 2026-05-25)
Python 3.10.12
Linux 6.18.33.2-microsoft-standard-WSL2 x86_64
22 logical CPUs
```

The system `cargo` command resolves through a blocked Snap wrapper. Commands
in this audit therefore use the direct rustup toolchain path.

