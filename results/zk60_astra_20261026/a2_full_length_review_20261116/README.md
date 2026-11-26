# Exact full-length A2 native validation

This development candidate preserves the six original layer-12 refusal cases:
3122, 3446, 3734, 4058, 4346 and 4670. Their full prompt lengths are 234, 174,
241, 181, 240 and 180 tokens. No input is truncated or retokenized.

`INPUT_RECOVERY.json` authenticates the original token streams. The raw IDs and
content files remain in `/private/tmp/astra-a2-t256-native-20261116/inputs`.
`HISTORICAL_REFERENCE.json` records 162 selected input/layer residual files,
authenticated through complete journal segments totaling 5,036,857,344 bytes.
It does not claim a new hash pass over the entire historical corpus. Raw
activations remain in private scratch too.

`EXPORT_PREPARATION.json` records an independent T256 export: all 581 source
and output payloads were hash-checked. Only `layer_12/exp.bin` changes, with the
matching score shift and exponential-member metadata. Full T256 rotary tables,
weights and tied tables remain unchanged. The derivative profile SHA-256 is
`48c3121855c28b19afd503eeee6989e6a67347b62cb750fede1be4972e273cff`.
This export is not an adopted app or production profile.

Four cases use the existing moderate violence/hate policies. The other two
use the exact historical strict-hate template. The new native driver registers
that template only in its test thread as `astra-a2-strict-hate-test-only/1`.
The production policy list is unchanged. There is no strict/moderate deployment
decision in this candidate. Its native source is copied from frozen package V;
the sole existing-source edit includes one child module behind `cfg(test)`.

The prepared pipeline has 23 guarded leaves:

1. Compile checking, release test build, the test-policy scope check, the 15
   existing classifier regressions, and native T256 admission for all six cases.
2. Six numerical sequence checks using the original T256 evaluator and the
   reviewed layer-12 change. Every active row at all 26 layers must equal the
   recovered historical reference. Trailing rows use token 11's real embedding.
3. For each case, an ordinary native proof followed by six separate native
   processes: verification, input-owner check, complete-item label, wrong model
   pin, wrong content, and saved-receipt corruption. The ordinary prover's
   sealing and proof passes must check all 26 layers against the full T256
   numerical sequences. No verifier-once or seal-ahead shortcut is enabled.
   Before each proof, the ordinary native head calculation also checks all
   3,072 normalized words and the exact historical integer margin.
4. An automatic audit of guard termination, all case counts, binary identity,
   the saved honest receipts, private log hashes and full input coverage.

Every heavy leaf uses the unchanged shared guard, normal polling, two threads,
ten-second gaps and a 55 GiB disk floor. Native logs, receipts and owner material
stay in private scratch; public reports contain metadata and hashes. The only
deleted files are new corruption copies after their rejection is checked.
The planning ceiling is 24 GiB of retained honest receipts, plus transient
corruption copies and build/sequence files. Announce that storage before launch.

Execution refuses to start while either the existing U/W parent or Y classifier
review controller lacks terminal evidence. Observe original sessions 40919 and
39460; do not launch duplicates. Once the current validation window ends, the
single fixed command is `python3 -B pipeline.py run <SOURCES.json SHA-256>` from
this directory, with the host's applicable execution permission.

Preparation and syntax checks have passed. Native compilation, admission,
forward parity, proofs and fresh verification for this candidate remain
unexecuted. A passed future run would cover these six original cases under the
declared development profiles. It would not establish held-out task quality,
external model authorization, privacy, formal soundness or production adoption.
Fresh processes share the local filesystem and BLAKE3 implementation; there is
no claim of OS-enforced witness isolation or an independent verifier algorithm.
