# Round-12 retained evidence

Final source: `972da4e`. The top-level `zk60_round12_validation.json` is an
unchanged copy of the completed runner report. `index.json` maps original
paths to byte-identical retained logs/scripts and records every SHA-256.
Duplicate proof files and the rebuilt binary stay in scratch space; their
full hashes and byte counts are retained in the final report.

`initial/` preserves the R32 baseline regression (expected failure against the
old verifier) and the first combined run (failed at the attention schedule
tests). That launcher incorrectly set HL_GPU=0, where the schedule gate
requires it unset. The conservative source hash also needed explicit review
after the R32 refusal branches. All 45 recorder call lines, 19 roles and
12 sumcheck sites match the old source; the executed trace fingerprints were
kept unchanged and pass in `final/`.

The exact runner scripts use pinned source/scratch paths. Reproduction needs
those inputs or explicit path adjustments, a fresh directory, two threads,
the shared heavy lock and per-build lock. The corrected launcher removes
HL_* variables and runs the CPU binary without GPU features. This is CPU
correctness/compatibility evidence; it is not a GPU or privacy qualification.

Logs retain original whitespace and hashes. The unchanged Python/native
suite retains round-11's 546-test validation and was not rerun in this round.
