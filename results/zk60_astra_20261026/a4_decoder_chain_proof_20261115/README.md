# Decoder chain proof preparation

This directory records independent work performed while the first-layer proof
batch waits for the shared heavy lock. `prepare_plan.py` checks all 26 trained
layer calibrations and group folds, authenticates the retained native output
files, verifies all 75 input/output carry links, and checks the classifier's
selection of real row 148. PREPARATION.json records 320 input digests. It does
not execute or qualify a proof.

All layers fit the proposed real149/T256 normalization class: tn=9, eps=2439,
and the reduced denominator stays below 2^23 over the entire I16 residual
class. Each layer's gate folds fit the existing coefficient and shift bounds.
The difference between its native activation scaling and the proof's aligned
scaling exactly matches the difference in product shifts. Both final norm
variants, cn=1024 and cn=7009, use the qualified final native row. Layers 7 and
12 retain their explicitly versioned score shift 6→7 and exp member 1→2 from
the qualified image candidate; these differ from the original export. The
preparation records both original and effective constants.

`prepare_models.py` has reconstructed all 26 numerical model files against
their archived byte digests. MODEL_METADATA files remain small and in this
directory; 3,039,614,944 bytes of model data stay outside the repository. The
bounded single-threaded reconstruction peaked at 80,527,360 bytes RSS and
needed no host approval (original tool session 89020, terminal exit 0).
MODELS.json pins 748 inputs and records every output digest. This is a model
preparation check, not another numerical or proof execution.

The existing run implementation already supports each layer's calibration and
gate denominator. Use `LayerRecord::own`, `RunStatement::new_bound_from_digests`,
`stage_shape`, and the streamed `BlockSource`/`RunWitnessSource` interfaces.
Retain distinct layer indices and bind all 26 manifest/table/model digests in
one trained statement. The current first-layer importer intentionally accepts
only layer zero; extending it requires a separately authenticated revision.

The separate source copy now implements loading one layer at a time, comparing
every actual builder word with the independently carried reference plane hashes,
and streaming each serialized receipt through the ordinary verifier. Internal boundaries need
256 data rows plus six mask/proximity rows at 4096 columns. Test a changed
middle-layer calibration, reordered or missing layers, changed carry roots,
and coherent forgeries on both sides of a joined boundary. The staged tests
currently include seven model controls, four serialized-stream controls, and
two complete 26-frame forgeries targeting the middle boundary's producer and
consumer separately. Their expected rejection sites are stage 12 output
equality and stage 13 input equality. No new proof tests have run yet.

The large reference/model fixtures for layers 1–25 were deliberately removed
after their earlier numerical qualification. The new models now match those
archived digests exactly. Every reference plane retains a SHA256 of all original
I64 words, so the staged comparator hashes the complete actual builder output
in that same order without recreating the large reference files. The earlier
numerical output/carry files remain available and were authenticated here.
No predecessor directory was changed.

`prepare_references.py` extracts 78 per-case reports into `references/`, including
layer zero's three reports, which were originally bundled only in FIXTURES.json.
REFERENCES.json records the original authenticated file and digest for each of
the 5,616 plane descriptions. Set ASTRA_CHAIN_REFERENCES to this directory.
INPUT_RELOCATIONS.json locates the identical archived first-layer source manifest
after its runtime-only model-location retry; earlier report hashes remain intact.

The existing classifier run includes a text token-embedding input stage. An
image producer requires a composition that consumes its authenticated residual
boundary instead. Reuse the final-norm/margin relations with an explicitly
bound row selector and both numerical variants; register a separate development
statement for the image chain. Bind the image producer, decoder chain, and
classifier to the same context, unit and boundary commitments. Merely verifying
three independent receipts does not establish that composition.

SOURCE_BASE.json records the exact first-layer candidate copied while its batch
was live. Any later repair to that candidate must be reviewed and ported before
qualifying this copy. The ordinary run verifier's internals are exposed only to
the containing private-block module so the test can stream frames; its checks
are unchanged. A test-only source hook can give the cheating prover a false
incoming-boundary oracle; it requires the explicit cheating switch and exact
plane extent. Ordinary verification still uses the actual commitment. The
chain adds an explicit frame-order/count wrapper and restores ordinary lookup
and verifier checks even while producing forged receipts.

The first-layer per-layer residual-unit repair and its four rejection controls
are ported here. Relative to SOURCE_BASE, four existing source files change
(the importer, reference comparator, tests and run source) and chain.rs is new.
The six inherited unit tests and all chain tests still require compilation.
The inherited matrix-forgery assertions now expect each private relation's
declared zero-check host. The original unlaunched seal and source are preserved
under revisions/before-host-slot-assertion; no proof relation was changed.

The chain importer derives and authenticates the shared export once per run,
then passes that owned object to each layer loader. Every numerical model and
metadata record is still authenticated on load; no global unchecked cache is
introduced. Future validation must use a separate cargo target and the supported
ZK60_MODELS root prepared by the first-layer retry.

The complete validation sequence is prepared in `batch.py`: fresh native check,
release build, six unit tests, three full-chain cases and both coherent boundary
forgeries. Successful leaves advance automatically under the unchanged shared
guard. `evidence.py` requires every ordered plane hash to match the archived
reference, all 26 frame indices and expected ordinary-verification prefixes,
and the specific producer/consumer rejection sites. A successful batch invokes
`audit.py` automatically; a failed leaf stops and retains its evidence.
`seal.py` authenticates the four frozen predecessor packages, all 26 models,
78 reference reports, original input relocations and the narrow source diff.
This sequence is prepared but has not been launched.

First-layer proof qualification, all-layer native compilation/qualification,
image/classifier composition, task quality, whole-proof privacy and production
acceptance remain open. This plan makes no adoption or performance claim.
