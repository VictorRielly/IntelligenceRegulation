# Coordinator's check of A37 (2026-11-27)

Checked by the Claude co-coordinator against its own downloads, not the researcher's. The handoff is
`20261127-apps-legacy-toolkit-custom-assertions.md`.

## What was done

- Own copies, fetched with a generic User-Agent, each file into a directory of its own, read as text with
  `python3 -I`, nothing executed: the ten files the handoff read, and two it did not (`sdk/src/assertion.rs` and
  `sdk/src/store.rs` of the Rust reader at the toolkit's pin). My ten copies have the byte counts the handoff gives.
- The handoff fetched the Rust reader at the short revision `0a29852`. I resolved it through the public commits
  address to `0a29852b0546596972c7105a7a510b12e050dc67` and fetched the Rust files at that full hash.
- 120 checks, all pass: `20261127-apps-legacy-toolkit-custom-assertions-recheck.py`, saved output beside it
  (`-recheck.out.txt`). Run as `python3 -I <script> DIR`, DIR laid out as the script's header says.

## Confirmed

Every quotation of the handoff that the script tests stands at the line given:

- The toolkit returns the whole store: the report type holds the Rust reader's store and one separate text
  (`lib.rs:82-86`, built and serialised at `156-163`); the words "assertion" and "label" occur in the toolkit's two
  source files only on two lines about a separate identity summary [COUNTED by the script].
- In the Rust reader at the pin, the match on the label has seven arms [COUNTED]; six name fixed labels or fixed
  endings; the last copies a CBOR or JSON assertion with any other label into the list (`manifest.rs:759-776`) and
  pushes nothing for binary and UUID boxes (`778-780`). The list is serialised without a skip (`112-113`).
- The JavaScript library passes the list on: one read of it (`manifest.ts:160`), sorted by instance, exposed as
  `data`, and filtered only by the `get` method on an exact label (`assertions.ts:48-57`).
- The older summary component's input type holds twelve fixed fields (`createL2ManifestStore.ts:35-48`); the
  function reads the assertion list on one line, for one literal label (`133`).
- The popover file does not contain the words "assertion" or "manifest"; it has a content slot and a trigger slot.

## What this check adds

1. **A label to avoid.** A label ending in `.metadata` does not reach the catch-all arm: it is parsed as the
   standard's metadata form, with `?` (`manifest.rs:752-753`). A reference record's label must not end that way.
2. **The link the handoff's last finding left unread.** `decode_data` only returns the stored data
   (`assertion.rs:282-284`). `as_json_object` returns an error for JSON text that does not parse and for CBOR that
   does not transcode (`assertion.rs:331-347`). So the `?` at `manifest.rs:763` and `770` leaves the manifest
   builder with an error, the store builder records a status and does not insert that manifest
   (`manifest_store.rs:223-225`), and the active label was already set (`206`).
3. **An earlier test the handoff did not see.** Before the manifest loop, the store loader at the pin tests the box
   itself and reports a failure to the validation log, followed by `?` (`store.rs:796-812` for JSON, `848-864` for
   CBOR). The reader builds that log with the default setting (`manifest_store.rs:259`) and returns a load error
   as an error (`275`).

So, as far as read, a custom record whose CBOR or JSON does not parse is not simply left out by the deprecated
reader. One of two things happens: (a) the load stops and the toolkit call returns an error; or (b) the load goes
on, the manifest that carries the record is missing from the result, and the library's next step reads a field of a
missing value (`manifestStore.ts:127`, `158`; `manifest.ts:133`, with no test before it). Which of the two depends
on the validation log's default at this pin, which was not read (at the newer version read for A36 the default is
to continue). Whether the library's outer read call catches the exception was not read either. Nothing was run.

This answers most of the queued item A39; what is left of it is named in the queue.

## Limits

Source text at two pinned commits. Nothing was built or run. No tree listing was fetched this time: file sizes are
compared with the handoff's stated byte counts (two independent downloads agreeing), not with a listing. Not read by
anyone: the toolkit's TypeScript types, the library's outer read call, the validation log at the pin, the selectors
behind the other input fields. This is the deprecated repository; it says nothing about a hosted viewer.

## What it means for a product

A reference carried as a CBOR map or JSON object under a domain label reaches the assertion list of the deprecated
library too; raw binary does not (the same rule as in A32 and A36). The label must not end in `.metadata`. The
record must be well formed: here a malformed one can cost the whole read, where on the newer library's second JSON
route it costs only that record. A producer should parse its own record back before embedding it. No shipped
component displays the record (A35); an integrator shows it in a panel of its own.
