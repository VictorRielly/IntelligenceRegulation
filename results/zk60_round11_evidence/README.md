# Round-11 retained evidence

The source validated here is `c8a342f`. `index.json` maps original run paths to
byte-identical retained files and records their SHA-256 hashes. Reports remain
unchanged from the completed runs. The initial review predates the combined
validation; its historical scope and caveats still apply.

The retained Python scripts are the exact run scripts, with pinned checkout
and scratch paths. Reproduction needs those pins and inputs or explicit path
adjustments, a fresh output directory, two threads and the shared heavy lock.
Never take the build lock outside the floors runner. `validate.py` captures
the dependency source hashes beyond the standalone floors manifest's scope.

Large public observation arrays remain in scratch space. Their proof/file
hashes are retained in the review and validation reports. Regenerate them with
the opt-in command in `docs/zkmatrix-poc/ZK60_FFN_MASK_DIAGNOSTIC.md`.
`captured_rank.py` consumes the initial `observations` directory and models
only the restricted per-column subset stated in its report. It does not
establish joint privacy or an upper bound on disclosure.

Logs retain original whitespace to preserve their hashes. The duplicate B4
proof and rebuilt CPU/GPU binaries are not added to Git. The frozen proof
hashes and lengths are retained in the manifest and validation report.
