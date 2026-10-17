# Export format changes (`zk60-trained-profile-export/1`)

The native lane's reader accepts the B3 layout (profile.json, layer_NN/
manifest.json + raw `.bin` arrays, seq_*/ x_in/x_out). Every change below is
recorded here BEFORE it appears in an export. None of them changes a field the
reader parses today.

## 2026-10-17, lane B4

1. **No schema change.** `profile.json` keeps schema `zk60-trained-profile-export/1`
   and every existing key. New information goes only inside
   `metadata_out_of_proof` (free-form): `calibration` = {T_cal, corpus,
   calibration_sequences, domains, fineweb_edu provenance}.
2. **Additional files in an export root (optional, the reader may ignore them):**
   * `README.md` (scope, constants, digests, fidelity) — already present in B3;
   * `rotation.json`, `rotation_sign.bin` (rotated exports; already added to the
     B3 rotated exports after their verification);
   * `token_io.json`, `embedding_int16.bin` — the layer-0 input as a public
     int16 lookup table [32000, 2048] (see `TOKEN_IO_SPEC.md`).
3. **Weight files shared by HARD LINK across exports with identical
   calibration**: `pg_rot1_b4_T128` (calibrated on T=128 sequences) is the
   reference; `pg_rot1_b4_T64_cal128` and `pg_rot1_b4_T32_cal128` reuse that
   calibration (`--calib-T 128`) and are evaluated and exported at T = 64 and
   T = 32. `b4_dedup.py` links a file only when its sha256 equals the
   reference's file at the same relative path. The files are byte-identical
   (same sha256 in each manifest) and are ordinary files, not symlinks, so a
   reader that rejects symlinks or path traversal sees exactly the B3 layout.
   Only the T-dependent files differ: `rope_cos.bin` / `rope_sin.bin`, each
   layer's `manifest.json`, `profile.json`, the sequence directories. Deleting
   one export directory leaves the others intact (hard links).
4. **Sequence selection.** With two held-out domains the exported sequences are
   the first sequence accepted at every layer in EACH domain (licence/docstring
   text and FineWeb-Edu), still with no fidelity-based choice; their manifests
   carry `source.domain`.

## 2026-10-17 09:30 UTC, lane B4 (value correction, no format change)

`profile.json` → `calibration_tool.sha256` was computed when the export was
WRITTEN, i.e. after the run; two B4 exports were written after an unrelated,
results-neutral edit of the tool files. Their records now name the code that
actually RAN (snapshot `tool_snapshots/b4_exports_20261017/`, every hash
checked) and carry a `calibration_tool.snapshot` pointer:
`pg_rot1_b4_T128` (profile sha256 now b418a1dd...) and `pg_rot1_b4_T64_cal128`
(now 0ad58b25...). `pg_rot1_b4_T32_cal128` was already exact (826f7641...).
The driver now hashes its tools at start. Apart from the regenerated
`README.md` files (which quote these hashes) no other byte of any export changed;
the B3 exports (`a_export_T32`, `pg_rot1_export_T32`, `dg_rot1_export_T32`)
are untouched and their records were exact (checked against
`tool_snapshots/b3_exports_20261017/`).
