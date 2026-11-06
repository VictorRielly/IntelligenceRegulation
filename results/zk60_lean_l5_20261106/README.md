# D63 step L5, the foundation: evidence (2026-11-06)

The report is §7 of `docs/zkmatrix-poc/ZK60_LEAN_ASSEMBLY_20261106.md`. Every job below ran through the zk60 resource
guard (class `cpu`) with `run_guarded.py`, detached with `start_new_session`.

## Inputs

| File | What |
|---|---|
| `blake3_test_vectors.json` | a copy of `test_vectors/test_vectors.json` of `github.com/BLAKE3-team/BLAKE3`, fetched 2026-11-06 from `raw.githubusercontent.com/BLAKE3-team/BLAKE3/master/test_vectors/test_vectors.json`; sha256 `dcb91ea8accc77e6d6e632af7cdc1a99a9f3ae78cf648da595c7d064db32f624` |
| `gen_vectors.py` | turns it into `formal/ZK60Formal/L5Vectors.lean` |
| `corpus.txt` | the agreement corpus written by `ops/zkp-mvp/gpu-metal/zkp-core/tests/lean_l5_export.rs` (TEST ONLY; public synthetic data): 5,359 records, 643,668 bytes |
| `mutate_corpus.py` | the negative control: six single changes to the corpus |

## Jobs

| Script | Log | What |
|---|---|---|
| `lean_file.sh`, `lake_target.sh` | `file1.log` … `file10.log` | the new Lean files while they were written (the errors fixed on the way are in these logs) |
| `export_corpus.sh` | `rust.log` | `cargo test --release --offline --locked -j 2 --test lean_l5_export` with `LEAN_L5_CORPUS=corpus.txt` |
| `run_l5check.sh` | `l5check.log` | the modules built, then `L5Check.lean` on the corpus (two runs) |
| `check_l5.sh` | `check.log` | the full `lake -d formal build` (`full.log`), the axiom audit (`axioms_l5.lean` → `axioms.log`), the source scan, the agreement check (`l5check_full.log`) and the negative control (`negative_control.log`) |

## Results

- Full build: 3,449 jobs, rc 0, no warning, no error.
- Axiom audit: 74 declarations; each shows only `propext`, `Classical.choice`, `Quot.sound` (or a subset).
- Source scan of the six L5 Lean files for `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
  `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`: none.
- Agreement check: `L5Check: 5553 checks, 0 failed`.
- Negative control: `L5Check: 5553 checks, 6 failed`, as required.
