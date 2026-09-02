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
