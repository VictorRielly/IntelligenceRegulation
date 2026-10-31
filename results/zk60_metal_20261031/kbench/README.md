# Standalone benches behind M4d / M4e (scratch harnesses, not part of the prover)

- `main.rs` + `Cargo.toml` (`kbench`): times variants of ONE slot's extension-round kernel on random
  extension tables, every later round of one sumcheck (half = cap/4 down to 1), best of three, and prints
  the summed partials so every variant is checked equal. Args: `<library.metal> <tables> <degree>
  <log2 cap> <kernel,kernel,...> [pairs per thread] [log2 thread cap] [threadgroup width]`.
- `gen.py`: writes the variants (B, C, D lazy / point-outer / unrolled; E, F one thread per point) from a
  library dumped with `HL_METAL_DUMP=<dir>`; `slot14_shieldstral_t128_m4e_karatsuba.metal` is the dump
  of Shieldstral slot 14 (64 tables, degree 5) the sweeps used.
- `run.log`, `sweep*.log`: the measurements quoted in ../README.md (M4e). E with one pair per thread is
  the form the prover now generates.
- `gl_mul_bench_main.rs` / `gl_mul_bench_run.log`: the Goldilocks multiply three ways (equal outputs).
- `helper_write_bench_main.rs`: the LogUp helper write per column vs one region (M4d).
- `alloc_bench_main.rs` / `alloc_bench_run.log`: first and second touch of fresh shared Metal buffers (M4f).
