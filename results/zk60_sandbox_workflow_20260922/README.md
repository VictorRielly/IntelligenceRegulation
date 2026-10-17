Sandbox workflow check: offline core build and tests with ordinary execution permissions. Source copied from the validated shaped integration, before any sumcheck optimization. No GPU, no Git write, no detached outside-sandbox launcher.

PASS: 50 unit tests and 2 integration tests; source hashes unchanged.
`validation.json` records the exact command and hashes; `core-tests.log`
contains the build/test output and `run.done` is zero. Elapsed time is a
shared-machine build diagnostic, not a proof benchmark.
