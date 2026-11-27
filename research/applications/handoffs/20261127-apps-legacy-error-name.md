# A42, what was left: the error name the legacy library sees for a JSON box that is not UTF-8

**Date:** 2026-11-27. **Who:** the co-coordinator (Claude), by its own reading, in place of a research tick.
**Evidence:** reading of public source at two pinned commits; every statement below is derived from the text.
Nothing was built or run, and no file with a bad record was read by either library.

## The question

Item A39 found that, at the revision of the older reader library the legacy toolkit pins (c2pa-rs
`0a29852b0546596972c7105a7a510b12e050dc67`), a custom assertion whose JSON box is not UTF-8 fails the whole load.
Queue item A42 asked, for the legacy JavaScript library (`c2pa-js-legacy` at
`c8c2912e2855c857277c0e1a6535a6db18e13c8e`): which error name does its `read` then see, and can that name be one of
the three the library ignores (`c2pa.ts` 289-296)? The first two questions of A42 were answered in the check beside
A39's handoff.

## What was read

Six files already downloaded for A39 (same bytes as its table lists) and nine more, each downloaded once with a
generic User-Agent into a directory of its own: the reader library's `error.rs` and `jumbf/boxes.rs`, the toolkit's
`error.rs`, and six small files of the JavaScript library's worker pool (`worker.ts`, `lib/pool/worker.ts`,
`lib/pool/error.ts`, `lib/pool/workerManager.ts`, `lib/pool/workerPool.ts`, `lib/poolWrapper.ts`). Lengths and
SHA-256 values are in the check script beside this note (`-check.py`; 97 checks, none failed; output in
`-check.out.txt`). Paths came from the repository's tree listing at the commit.

## Answer

1. **The error keeps its own kind all the way out of the Rust part.** `Assertion::from_data_json` builds an
   `AssertionDecodeError` with cause `BinaryDataNotUtf8` (`assertion.rs` 442-447). The `?` at `store.rs` 796 turns it
   into `Error::AssertionDecoding` (`error.rs` 42, the only conversion for that type). No caller replaces it:
   `from_jumbf` returns it as it is unless it is the pre-release error (`store.rs` 1383-1391), and it passes
   `load_cai_from_memory` (3968), `get_store_from_memory` (4143, which only logs), `load_from_memory_async` (4355) and
   `from_bytes_async` (`manifest_store.rs` 264, 275). The toolkit wraps it as `Error::C2pa` (`toolkit/src/error.rs`
   18; `toolkit/src/manifest_store.rs` 20, 34).
2. **The name is the debug text of that value.** `as_js_error` sets the JavaScript error's name to
   `format!("{:?}", err)` (`toolkit/src/lib.rs` 66). The decode error writes its own debug text
   (`assertion.rs` 598-601, 509-517), so for an assertion labelled `org.example.proof` the name is
   `C2pa(AssertionDecoding(could not decode assertion org.example.proof (version (no version), content type json): binary data could not be interpreted as UTF-8))`.
3. **It cannot be one of the three ignored names.** Each ignored pattern is anchored at the start and needs
   `ProvenanceMissing`, `JumbfParseError(`, `JumbfNotFound` or `JumbfBoxNotFound` right after `C2pa(` (`c2pa.ts` 291,
   293, 295). The name above has `AssertionDecoding(` there, whatever the label holds. It is not the remote-manifest name either (318). So
   `handleErrors` reaches `throw error` (330) and `read` rejects.
4. **The name survives the worker.** `getReport` in the worker has no handler of its own (`worker.ts` 32-40). The
   worker shell catches, copies the error's own properties into a plain object (`lib/pool/worker.ts` 41-45;
   `lib/pool/error.ts` 16-18) and posts it; the manager rebuilds an `Error` from those properties and rejects with it
   (`lib/pool/workerManager.ts` 38; `lib/pool/error.ts` 26-31); the pool passes the rejection on
   (`lib/pool/workerPool.ts` 68-71, 95; `lib/poolWrapper.ts` 42) to the `catch` in `read` (`c2pa.ts` 237, 246-247).
   A name set by assignment is an own property by the language's rule. The library's own four named cases depend on
   the same path.

## One more exit found on the way

A38's handoff already records, for the current reader library, that an assertion with a missing data box aborts the
load with `JumbfBoxNotFound`. The older revision has the same exit: inside `get_assertion_from_jumbf_store` the JSON,
embedded-file, CBOR and UUID arms each end `.ok_or(Error::JumbfBoxNotFound)?` (`store.rs` 794, 827, 830, 847, 879),
and the accessor gives nothing when the superbox has no first data box or when that box is of another kind
(`jumbf/boxes.rs` 295-302, 304-311).

Added here: **in the legacy JavaScript library that error is one of the three it ignores.** Its name is
`C2pa(JumbfBoxNotFound)`, which matches the third pattern (`c2pa.ts` 295), so `handleErrors` returns `null` (327) and
`read` resolves with `manifestStore: null` (256-259). The page gets the same answer as for a file with no manifest at
all, and no error.

## Not determined

- Which bytes make the box reader produce a superbox with no first data box, or with a first data box of another
  kind than the description's type says. The box reader in `jumbf/boxes.rs` was not read.
- Whether the binding's `set_name` behaves as plain assignment. Its source was not read and nothing was run.
- Whether the Rust part returns a store at all for a signed claim with a box that does not parse (A43, open), and
  what the current web reader does (A41, open).

## What it means for a product

A record of ours that carries a proof reference can fail in two different ways in a page built on the legacy
library. A JSON box with bad encoding gives the page an error. A box that is missing or of the wrong kind makes the
whole file read as having no manifest, with no error to notice. The rule from A38 and A39 stands and gets one more
test: before release, each written file is read back with both readers, and the read must return a manifest store,
not only "no error".

Limits: two source trees at two commits; this says nothing about what any service does.
