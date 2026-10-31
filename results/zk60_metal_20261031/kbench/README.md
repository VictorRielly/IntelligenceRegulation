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
- `gen2.py` (M4g): variants E (the M4e form), L (E's loads and line values with the body replaced by a
  sum: a floor), G (one point per SIMD group of 32 lanes, point 1 not launched when `eval_one == 0`),
  H (G with the line value's step times `d` as a two-product small-integer multiply) and LG (G's floor).
  `main.rs` now takes `eval_one` as a 9th argument (1 by default), gives G/H/LG their grid, skips point 1's
  partial when it is not evaluated, and reuses one partials buffer across rounds (a fresh shared buffer's
  first touch is slow here, M4f). `sweep_m4g.sh` / `sweep_m4g.log`: the measurements quoted for M4g (the
  script's paths are the session scratchpad it ran from).
- `gl_mul_bench_main.rs` / `gl_mul_bench_run.log`: the Goldilocks multiply three ways (equal outputs).
- `helper_write_bench_main.rs`: the LogUp helper write per column vs one region (M4d).
- `alloc_bench_main.rs` / `alloc_bench_run.log`: first and second touch of fresh shared Metal buffers (M4f).
