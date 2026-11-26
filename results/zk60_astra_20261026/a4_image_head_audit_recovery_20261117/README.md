# Classifier review audit recovery

All eight native leaves of the original Y batch passed. Original session 39460
nevertheless exited 1 because its final Python evidence audit missed the first
record printed by each of four Rust tests: libtest put its `test NAME ... ` prefix
on the same line. The original controller, terminal records, sources, logs and
receipts remain unchanged.

`recover.py` reproduces the original parser failure, removes only the four exact
known libtest prefixes in memory, then applies the original strict evidence and
container checker. It also checks every source pin, the eight clean guards,
native test counts, complete reference-plane comparisons and saved file hashes.
Missing, duplicate, unknown-role and malformed-digest evidence are still refused.

The recovery audit passed: eight honest cases (including two explicitly
constructed positive cases), 80 coherent forgeries refused by fresh verifier
processes, 192 wire controls, 73,784 reference words and all 88 retained receipts.
No compiler, prover or verifier was rerun. `terminal.json` is the new audit-only
completion record; it preserves the original exit 1 and original terminal hash.

The frozen V package is unchanged. This answers the saved-receipt, positive-bit,
margin-preserving verdict-control and case-coverage evidence gaps for the declared
standalone development cases. Public model preimages are serialized independently,
but the native verifier still shares its loader and hash implementation with the
prover, and roots remain public statement handles. Fresh processes share the
filesystem. This does not establish external trusted-model acceptance, actual
image task quality, privacy, formal soundness or production adoption.

Raw receipts remain in private scratch. Their full hashes and the original native
log hashes are in RESULT.json; the package contains sources, metadata and reports.
