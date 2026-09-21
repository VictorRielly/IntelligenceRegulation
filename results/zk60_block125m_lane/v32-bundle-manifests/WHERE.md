# The stage-32 bundles are OUTSIDE this repository

`run-o-dense-w14` and `run-p-zero-w14` are two honest **two-block** run
captures at `Shape::rung_w14` — the 125M row width (`log_cols = 14`, encoded
2^16), the 125M head size (`head_dim = 64`) and the 125M endpoint log — in
schema `hashline-native-capture/5-run` (the array store) with the public
tables' VALUES.

They are **50.6 MB and 49.5 MB**, past the ~40 MB a file in this repository
should be, so the bundles themselves live where the 125M captures live:

```
/home/victor/zk60-artifacts/run-o-dense-w14
/home/victor/zk60-artifacts/run-p-zero-w14
```

Committed here instead: each bundle's **`manifest.json`** — which records
every file's length and SHA-256 and pins 38 source files at commit
`11703c9` — and each bundle's own **`README.md`**, the note the writer put
inside it. The self-check that reads the bundles off disk and verifies every
recorded length and digest is `../v32-bundle-check.log` (0 mismatches).

To regenerate them, byte for byte, from this commit:

```
HL_RUN_CAPTURE_DIR=<a directory outside the repository> \
HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=11703c9 \
cargo test --release --lib \
  private_block::run_capture_tests::write_the_w14_gate_bundles -- --ignored --nocapture
```

| bundle | `run.json` | stage files | `arrays.bin` | total |
|---|---:|---:|---:|---:|
| `run-o-dense-w14` (FULLY DENSE, generic) | 34,845 B | 3,695,023 / 4,415,868 B | 42,424,904 B | **50,575,731 B** |
| `run-p-zero-w14` (all-zero, degenerate) | 34,828 B | 3,694,816 / 4,418,843 B | 41,380,544 B | **49,533,887 B** |

They are **not gate evidence** (ruling T-6) and not a privacy result: they
are the INPUT to the independent Python run gate, never its verdict.
