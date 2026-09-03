# hashline — the hash-based comparison prototype (U-PERF3 lane UU)

A prover + verifier for THE SAME statement the lattice engine
(`zkmatrix-rs`) proves at 12x512 — the 125M FFN pass, 12 layers x 512
tokens, exact int8 semantics (TARGET_CONTRACT.md section 2) — built on a
hash-based, small-prime-field stack so the two proving channels can be
measured side by side (docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md
section 3).

Stack: Goldilocks p = 2^64 - 2^32 + 1 with the quadratic extension
F_p[u]/(u^2 - 7) for challenges; a Ligero/Brakedown-class multilinear
polynomial commitment (rows Reed-Solomon encoded via NTT, blake3 Merkle
over columns, evaluation = clear row-combination + random column checks);
the matrix-multiplication sumcheck for the matmuls; LogUp lookups with
committed helper columns for the SiLU table and every range/requant
fact; zero-check sumchecks for the Hadamard/requant identities;
Fiat-Shamir over blake3. Primitives are hand-rolled (see the rung-0
record in PROGRESS_UPERF3.md, Agent UU status). Not zero-knowledge (a
prototype for the throughput row; the Ligero ZK masking is not built).

Build:
    flock /tmp/zk-build.lock cargo build --release --manifest-path hashline/Cargo.toml
Witness: `M125_EXPORT_DIR` (default the WSL re-export under
results/m125_ffn_export_wsl/).

    hashline check-export                   the export's sidecar digests reproduce
    hashline chain [layers]                 the exact integer chain reproduces every z digest
    hashline matmul <layers> <t>            the g/u matmul sumcheck differential + tamper legs
    hashline layer <l> <t> [--all-tampers]  prove + verify one layer (+ six tamper legs)
    hashline pass <layers> <t>              the chained multi-layer pass, timed (the comparison row)
    opts: --threads N --log-cols N (14) --col-checks Q (256) --inv-rate R (4)
          --tamper flipx|flipw|rem|table|requant|z --tamper-idx I --no-verify

The measured row (12x512, 8 threads, CPU only, 2026-09-02): prove
23.0 s p50, verify 2.8 s, proof 66.8 MB, peak RSS 1.56 GB, 1.26e9
proven MAC/s — results/hashline_pass_12x512.md.

GPU (U-PERF3 lane XX, 2026-09-02): the prover's commitments (NTT +
blake3), zero-checks, helper columns, evaluation claims and opening
row-combinations run on the device behind `--features gpu-cuda`
(cudarc + NVRTC, the same toolchain as zkmatrix-rs) and `HL_GPU=1`;
the proof bytes are byte-identical to the CPU prover's (`--proof-out`
+ the `PROOF sha256` line are the gate). Build:
    CUDA_ROOT=/home/victor/cuda-root \
    LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib \
    CARGO_TARGET_DIR=hashline/target-gpu cargo build --release --features gpu-cuda --manifest-path hashline/Cargo.toml
Run with `HL_GPU=1` (and the same LD_LIBRARY_PATH); `hashline gpu-probe`
checks the device field / NTT / blake3 against the CPU code;
`HL_GPU_VERBOSE=1` prints per-kernel timings. Measured (12x512, 8T +
RTX 4070 Laptop): prove 3.40 s p50, verify 0.42 s, RSS 0.78 GB, VRAM
2.43 GB, 8.5e9 proven MAC/s — results/hashline_gpu_12x512.md.

Zero knowledge for the activations (U-PERF3 lane ZA, 2026-09-02): `--zk
--seed N` proves the same statement in mode P1 (inputs/activations
private, weights public): pad rows on a coset + mask rows for the A and
H commitments, masked sumchecks (CFS masking polynomials opened from a
per-layer mask commitment) with a last-round extension that masks every
private terminal, committed multiplicities, salted leaves; the design is
src/zk.rs's module doc. The proof bytes are byte-identical CPU vs GPU
under the same seed (`PROOF sha256 ... [ZK seed N]`). Measured (12x512,
8T + RTX 4070 Laptop): prove 3.93 s p50, verify 0.38 s, 87.2 MB, 0.90 GB
RSS + 3.03 GB VRAM (non-zk on the same tree 2.46 s / 66.8 MB) —
results/hashline_zk_12x512.md. `layer <l> <t> --zk --all-tampers` runs the
tamper legs under `--zk`; the uniformity test is
`cargo test --release zk_openings -- --nocapture`.
