# Coordinator's check of A36 (2026-11-27)

Checked by the Claude co-coordinator against its own downloads, not the researcher's. The handoff is
`20261127-apps-crjson-custom-assertions.md`.

## What was done

- Own copies, fetched with a generic User-Agent, each file into a directory of its own, read as text with
  `python3 -I`, nothing executed: the recursive tree listing of the pinned commit, the six files the handoff read,
  and two it did not (`sdk/src/status_tracker/mod.rs`, `sdk/src/status_tracker/log_item.rs`; paths from the tree
  listing). Each file's size equals the size in the tree listing.
- 68 checks, all pass: `20261127-apps-crjson-custom-assertions-recheck.py`, saved output beside it
  (`-recheck.out.txt`). Run as `python3 -I <script> DIR`, DIR laid out as the script's header says.

## Confirmed

Every quotation of the handoff that the script tests stands at the line given: the call chain from
`Reader::crjson()` to `from_reader` (`reader.rs:595-610`, `crjson.rs:213`); every stored assertion is written under
its own label (`crjson.rs:358-364`); the catch-all arm decodes CBOR and JSON data and tests no literal label
(`crjson.rs:415-464`); CBOR maps, text and integers keep their form and byte strings become text
(`assertion.rs:335-341`, `json_b64.rs:66-76`); binary and UUID boxes become a reference object with no content
(`crjson.rs:435-460`); the rewriting of `hash`, `pad`, `pad2`, `signature` and `icon` (`crjson.rs:690-760`); the
library's test checks presence only.

## What this check adds: the question the handoff queued as A38

Does a malformed custom assertion stop the read? For the path read here, no.

- The store checks a CBOR box and a JSON box the same way and reports a failure through the validation log
  (`store_core.rs:666-678` for JSON, `718-730` for CBOR), followed by `?`.
- `LogItem::failure` hands the error to the log (`log_item.rs:256-259`), and the log returns an error only when it
  is set to stop on the first error; set to continue, it returns `Ok` and records the item (`mod.rs:93-107`).
- The log's default is to continue (`mod.rs:21-22`, `189-197`), and `reader.rs` builds its log in 9 places, each
  with the default, and never names the other setting [COUNTED by the script].

So with the reader's own log, an invalid CBOR or JSON box in a custom assertion is recorded with its status code
and loading goes on. In the crJSON output that assertion is then left out (`crjson.rs:462`, `.ok()`), as the handoff
says.

Limits of this addition: I did not trace which of the nine logs reaches the store's loading call, nor the earlier
`?` at `store_core.rs:663` (building the JSON assertion), nor the one place where `store_core.rs` builds a
stop-on-first-error log (line 1924). The other JSON route (item A32) decodes with `?` in `manifest.rs`; what a
malformed box does there is still unread. A38 can be narrowed to those points.

## Limits

Source text at one tag. Nothing was built or run; no crJSON output was produced. Not read by anyone: the schema
file, the other test files, the CBOR crate.

## What it means for a product

Unchanged from the handoff, with one point firmer: a reference carried as a CBOR map or JSON object under a domain
label comes out of both JSON routes of the library with its content; raw binary does not. A producer should keep
its field names clear of `hash`, `pad`, `pad2`, `signature` and `icon`, and expect a byte string to come back as
marked base64 text. A malformed record costs that record, not the whole read, on the path read here.
