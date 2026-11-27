# Coordinator's check of A38 (2026-11-27)

Checked by the Claude co-coordinator against its own downloads, not the researcher's. The handoff is
`20261127-apps-malformed-assertion-load.md`.

## What was done

- Own copies of the eight source files the findings rest on, fetched with a generic User-Agent from the raw address
  of the pinned commit, each file into a directory of its own, read as text with `python3 -I`, nothing executed.
  Each copy has the byte length and the SHA-256 the handoff's table lists.
- 88 checks, all pass: `20261127-apps-malformed-assertion-load-recheck.py`, saved output beside it
  (`-recheck.out.txt`). Run as `python3 -I <script> DIR`, DIR laid out as the script's header says.
- Read by eye, not only matched by the script: the two box arms of the store's assertion loader
  (`store_core.rs:657-735`), the caller's error arm (`1295-1316`), the two constructors (`assertion.rs:425-449`),
  the decoder (`assertion.rs:333-342`), the catch-all arm of the manifest conversion (`manifest.rs:536-554`,
  `669-694`), the reader's loop over claims (`reader.rs:886-963`), its three accessors (`725-746`), and the log
  (`mod.rs:98-108`, `192-197`; `log_item.rs:256-259`).

## Confirmed

Every statement of the handoff that the script tests stands at the line given.

- **The log.** A failure handed to the log comes back as `Ok` unless the log was built to stop on the first error;
  the default is to continue. The reader builds nine logs, all with the default, and never names the other setting.
- **Invalid CBOR, and UTF-8 text that is not JSON.** The store tests the box, hands the failure to the log, and with
  the default log goes on: the assertion is still built and stored in the claim (`store_core.rs:715-734`, `663-689`,
  `1302`).
- **A JSON box that is not UTF-8.** The constructor returns an error before the log is asked (`assertion.rs:437-442`),
  the loader returns it (`store_core.rs:1315`), and the reader's read fails (`reader.rs:239`).
- **The manifest map.** After every load the reader converts each claim (`reader.rs:896-915`). The conversion's
  catch-all arm decodes a CBOR or JSON assertion again, with `?` (`manifest.rs:673`, `681`; `assertion.rs:335-340`).
  For a box that does not parse this is an error, so the conversion of that whole manifest fails; the reader logs
  "Failed to load manifest" and, with the default log, goes to the next claim (`reader.rs:930-936`). The map is
  filled at one line only, in the success arm (`928`). So the manifest is absent from `manifests()`, and
  `active_manifest()` returns `None` when it was the active one, while `active_label()` still names it (`727`,
  `735`, `958`).
- **The crJSON output** reads the store's claims and leaves out only the assertion (`crjson.rs:236`, `462`).

## What this check adds

- **This corrects the last sentence of my check of A36.** I wrote there that a malformed record "costs that record,
  not the whole read, on the path read here". That holds for the crJSON output. On the manifest map, which is the
  route an application normally uses, the same record costs the whole manifest: its signer, its actions and every
  other assertion disappear from the map, and only the status list says why.
- **Where the failure appears.** The store accepts the box and records a status; nothing fails until the reader
  converts the claim. The consumer then sees a file with no active manifest. Whether the library's own writer can
  produce such a box at all was not read; a producer that builds its boxes by other means gets no protection from
  this path.

## Checked at its end points only

The handoff's chain from the six loading calls in `reader.rs` to `Store::from_jumbf_with_context` is checked at both
ends (the six calls; the three calls in `store_io.rs:1315`, `1351`, `1400`; `store_core.rs:988`, `1295`), not
function by function through `store_io.rs`.

## Limits

Source text at one tag. Nothing was built or run, so no file with a malformed box was read by the library. Not read
by anyone: the status-code strings and `code_from_error`, the hash check of a claim whose box is malformed, the
callers of the ingredient loader that builds the one stopping log (`store_core.rs:1924`), the async variants. The two
items the tick queued (A40, A41) cover the first two and the web reader's behaviour when the active manifest is
absent.

## What it means for a product

A reference carried as a custom assertion must be well-formed CBOR or UTF-8 JSON, and the producer must test its own
output with the pinned reader before release: a single bad record hides the whole manifest from the reader's
manifest map. A verifier that wants to show "record present but unreadable" has to read the crJSON output together
with the status list, not the manifest map alone. This is a finding about one open library at one tag; it says
nothing about what any service does with such a file.
