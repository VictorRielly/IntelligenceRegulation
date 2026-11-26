# First trained image decoder proof candidate

The isolated source imports the authenticated first layer used by the qualified
numerical decoder. It adds a distinct real149/T256 W16 development profile,
strict symmetric I16 lookups for eight norm/attention roles, and a trained model
statement. Its endpoint uses 4096 columns and 261 commitment rows, matching the
image-input producer's data geometry for later composition.

Status: the first revision passed native check, release build and five unit
tests. Its proof stopped on a missing default checkpoint path. An authenticated
regular hardlink and the existing ZK60_MODELS setting corrected that location.
The retry authenticated the checkpoint and then stopped before witness
construction: the export declares per-layer units, whereas the legacy loader
looks for a scalar and defaults to 1. The revised importer now requires all 26
input/output units to match the model exactly and rejects conflicting optional
scalar values. Four rejection controls are included in a sixth unit test.
Both failed source revisions and the original executable are preserved. This
Rust change requires a fresh check, build and test sequence; build reuse is
disabled. This revision passed the fresh build, six unit tests and all three
honest serialized proof cases, matching all 72 planes each. Its first forgery
was correctly rejected by the Q zero-check host (slot 15), but the test expected
the private Q matrix slot (5). The revised assertions now require the declared
host for each private matrix relation; the audit checks those same named sites.
All failed source, executable and attempt evidence is preserved. The complete
batch still needs to pass before qualification. The earlier standalone
conversion preflight is qualified
separately in [ADAPTER_REVIEW.md](ADAPTER_REVIEW.md). The W16 implementation adds
affine range queries without extra witness limbs; the earlier discussion of a
byte-limb implementation is not the chosen integration.

`seal.py` authenticates the frozen predecessors and all source/model/fixture
inputs. `batch.py <SOURCES.json SHA256>` executes seven fixed, sequential,
guarded steps: check, release build, six unit tests, three trained proof cases,
and coherent forgeries. Each case compares the actual proof builder with all 72
reference planes before producing and verifying a serialized receipt. Black
also runs 12 wire/statement controls. Eleven forged proofs target nine matrix
definitions and two scalar-preserving norm range changes.

The batch records each result, stops on failure, and needs no decisions between
successful steps. Source pins are checked before each step. Resource admission,
HOLD markers, process checks, and the 55 GiB disk floor remain in force. After a
successful batch, `audit.py <attempt-directory>` authenticates its evidence and
writes RESULT.json. Failed attempts remain available for diagnosis.

This candidate does not yet compose with the image producer, prove all 26
decoder layers or the classifier, establish task quality or whole-proof privacy,
or change an installed profile. No raw receipts or model arrays are saved in
the repository. Timing is shared-host functional evidence, not a benchmark.
