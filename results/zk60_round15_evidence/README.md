# Round 15 retained evidence

The successful final run is `final/`: source 612ff9c, suite v6, exit marker 0.
Raw commands, exits, resource logs, test counts, binary identities, crate trees,
lock hashes, and all frozen proof hashes are in the report and manifest.
Proof binaries, cached weights, Cargo build products and secret material are
not copied here. All new witness/key fixtures are deliberately public tests.

`first-python-run/` preserves the broad 659-test run at 22c9b35: 658 passed,
one stale help-text assertion failed. All affected proof tooling is rerun on
the final source. Unchanged native/freezing results belong to that initial run,
not a claimed final-source full-suite run. The typed-core merge landed while
that first run finished tests of unchanged native sources.

`interrupted-run/` preserves the subsequent 8c60dfb run's successful tooling,
decoder, core-debug and build checks and the incomplete floors. It was stopped
before proof cases during CPU tests, to isolate storage-feature Cargo artifacts;
marker 143 means interrupted, never passed. `review/artifact-probe/` shows the
shared-target binary replacement and isolated-target full-hash preservation in
a tiny independent Cargo fixture. The runner regression failed before the fix.

`review/` also retains the CL21 before/after CLI checks on synthetic manifests
in real temporary Git checkouts, the original validator source, and the corrected
CL20 probes (identical source to round14) plus parity/log-digest checks.

Reproduce the CL21 regression from a repository retaining this history:

```sh
python3 results/zk60_round15_evidence/review/reproduce_cl21.py . /tmp/cl21-review
```

The scripts under `runners/` retain their original paths and source pins; a new
run needs fresh output directories and the documented heavy/build-lock setup.
`index.json` hashes every retained file except itself. This evidence establishes
bounded compatibility and correctness, not privacy or throughput acceptance.
