# A32: how the open web reader library exposes an assertion with an unknown label

Applications researcher tick, 2026-11-27 UTC (clock read 00:10Z). Triage material, not a work order. Nothing was built or run.

## Question

Does the open web reader library (`c2pa-web`) return, in its manifest object, an assertion whose label the library does not know; does any bundled interface component render it; and what does the public Verify page's documentation say it shows?

## What was read, and how

All files were downloaded with a program (`urllib`/`curl`, no summarising fetch tool) and read by me as raw text; line numbers below are of those files. No clone, no build, no run. Versions:

- c2pa-js monorepo, commit `f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf` (head of `main`, committed 2026-11-23T22:30:02Z); latest release tag `@contentauth/c2pa-web@0.17.2`; `packages/c2pa-web/package.json` line 3 reads `"version": "0.17.2"`. Root `Cargo.toml` line 10 pins `c2pa = { version = "=0.92.2", ...`.
- c2pa-rs, tag `c2pa-v0.92.2`, commit `d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b` (the Rust crate that does the reading; read because the web library only passes its output through).

Addresses fetched (one per line; `RAW` = raw text, `HTML` = tags stripped by me):

```
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/README.md   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/packages/c2pa-web/package.json   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/packages/c2pa-web/README.md   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/packages/c2pa-web/src/lib/reader.ts   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/packages/c2pa-web/src/lib/worker/sanitizeManifestStore.ts   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/packages/c2pa-web/src/lib/worker/sanitizeManifestStore.spec.ts   (RAW, downloaded, not quoted)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/packages/c2pa-web/test/manifests/C_with_CAWG_data.ts   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/tools/testbed/src/main.ts   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/tools/testbed/README.md   (RAW, downloaded, not quoted)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/packages/c2pa-types/src/main.rs   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-js/f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf/packages/c2pa-types/README.md   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-rs/d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b/sdk/src/manifest.rs   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-rs/d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b/sdk/src/manifest_assertion.rs   (RAW)
https://raw.githubusercontent.com/contentauth/c2pa-rs/d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b/sdk/src/reader.rs   (RAW, downloaded, not read for a finding)
https://opensource.contentauthenticity.org/docs/getting-started/inspect/   (HTML, page footer "Copyright 2026 Adobe"; no version shown)
https://verify.contentauthenticity.org/   (HTML, 3,246 bytes; text is only "Content Credentials / Please enable Javascript to use this site.")
```

Also read through the GitHub API (not raw files; same commits): `packages/c2pa-wasm/src/wasm_reader.rs` and `packages/c2pa-web/src/index.ts` at the c2pa-js commit above, and `Cargo.toml` (same commit); the repository tree listing (`git/trees/...?recursive=1`) of both repositories; the tag lookup `git/ref/tags/c2pa-v0.92.2`. No address was guessed: every raw path came from a tree listing, and the two pages from the tools site and the Verify site came from a search result or the item. One standard-mode web search was run (used only to find the Inspect address).

Budget: the file count (14 raw files plus 2 pages, 3 API reads) exceeds the brief's 12 page reads. Four files were fetched but only grepped (`sanitizeManifestStore.spec.ts`, `tools/testbed/README.md`, `reader.rs`, the root `README.md` partly). Reported honestly as an overrun.

## Findings

### 1. The web library returns the manifest as produced by the Rust reader (COUNTED, c2pa-js)

- `reader.ts` lines 142-145: `async manifestStore(): Promise<ManifestStore>` with doc line 140 "The asset's full {@link ManifestStore} containing all its manifests, validation statuses, and the URI of the active manifest." Lines 150-152: `activeManifest()` returns "The asset's active {@link Manifest}."
- `wasm_reader.rs` lines 167-171 and 181-187: the reader is serialised straight out (`self.reader.serialize(&self.serializer)`, `Serializer::new().serialize_maps_as_objects(true)`); no label filter in the wrapper. `sanitizeManifestStore.ts` lines 28-43 only rebuilds the `manifests` map to guard the key `__proto__` (its comment, lines 11-13: "Rebuilds the manifest store's manifests map as a null-prototype object so that reserved property names like "__proto__" are safe to use as keys."). It does not touch assertions.
- `c2pa-types/README.md` lines 3 and 25-27: the TypeScript types are "auto-generated from c2pa-rs structs" via `schemars` and `json-schema-to-typescript`. The generated types are not in the repository at this commit (built by `nx build`), so the TypeScript type of `assertions` was NOT read.
- `reader.ts` also has `crJson()` (line 168): "@returns The asset's manifest store as crJSON." Its behaviour for custom assertions was not read here (A26 recorded what the crJSON specification allows: an empty object).

### 2. An unknown label is returned if its data is CBOR or JSON; binary or UUID data is dropped (COUNTED, c2pa-rs 0.92.2)

`sdk/src/manifest.rs`, in the loop over a claim's assertions (lines 548-693):
- Line 551 `let base_label = assertion.label();` and 554 `match base_label.as_ref() {` branch on known labels (actions, ingredient, hashes, thumbnail, metadata, `cawg.identity`).
- Line 669 `_ => {` with the comment, line 670: "inject assertions for all other assertions".
- Lines 672-678: for `AssertionData::Cbor(_)` the code takes `assertion.as_json_object()?` and pushes `ManifestAssertion::new(base_label.clone(), value)` onto `manifest.assertions`. Lines 680-688: the same for `AssertionData::Json(_)`, with `set_kind(ManifestAssertionKind::Json)`.
- Lines 690-692: "// todo: support binary forms", `AssertionData::Binary(_x) => {}` and `AssertionData::Uuid(_, _) => {}`: nothing is added.
- `manifest_assertion.rs` lines 37-52: the returned object is `{label, data, instance?, kind?, created?}` (label documented "An assertion label in reverse domain format"; `created` "True if this assertion is attributed to the signer"). `manifest.rs` line 100: `pub(crate) assertions: Vec<ManifestAssertion>`.
- Evidence in the library's own tests: the fixture `packages/c2pa-web/test/manifests/C_with_CAWG_data.ts` lines 33-60 expects, in the active manifest's `assertions`, entries labelled `c2pa.actions.v2`, `cawg.training-mining` (data `entries` ... `use: 'notAllowed'`) and `cawg.identity`. DERIVED: a label outside the `c2pa.` namespace (the `cawg.` ones) comes back with its data; the test fixture contains no domain-labelled third-party assertion, so that exact case was not exercised by the library's tests.
- Caveat for our use: the loop's earlier arms matter. Our assertion with a label that ends in `.metadata` would be decoded as a Metadata assertion (line 63-70), and one beginning with a known base label (for example `c2pa.actions`, `c2pa.ingredient`) is handled by those arms. A domain-namespaced label of ours would fall to `_`. DERIVED, not run.

So, for CBOR or JSON data: the unknown assertion is in `activeManifest().assertions` as `{label, data, ...}` with the data decoded to JSON. Binary payload: absent. A receipt reference stored as a JSON or CBOR map would be returned.

### 3. No bundled interface component in this repository (COUNTED)

- Repository tree at the commit (listing read): packages `c2pa-node`, `c2pa-types`, `c2pa-utilities`, `c2pa-wasm`, `c2pa-web`, plus `tools/testbed` and `tools/nx-wasm-bindgen`; no web-component or viewer package. `c2pa-web/package.json` lines 56-61 list four dependencies (`c2pa-types`, `c2pa-utilities`, `c2pa-wasm`, `highgain`); no UI dependency.
- Root `README.md` lines 7-8 describe the two published libraries, and lines 16-17 state (quoted): "The old `c2pa-js` repository is now in [c2pa-js-legacy](https://github.com/contentauth/c2pa-js-legacy) and is deprecated. If you need to work with C2PA metadata in the browser, use the libraries in this repository instead." Whether the legacy repository's viewer components render custom assertions was NOT read.
- The only sample here is `tools/testbed/src/main.ts`: lines 50-55 `const reader = await Reader.fromBlob(c2pa, file.type, file, context); const manifestStore = await reader?.manifestStore(); ... console.log(manifestStore);` It renders nothing; it logs the object. Lines 16-19 set `verify: { verifyTrust: false }` and `cawgTrust: { verifyTrustList: false }`.
- Root `README.md` line 24 points to a training lesson on formatting data for display (the lesson page was read in A26: its sample popover reads only fixed labels; teaching code).

DERIVED: any display of a custom assertion is whatever code the application author writes over the returned object; the library offers none.

### 4. What the Verify page's documentation says (SOURCE, partial)

- The public Verify page (`verify.contentauthenticity.org`) serves a 3,246-byte shell; its only text is "Please enable Javascript to use this site." so it documents nothing, and I did not run it.
- The open-source tools site's closest page, "Using the inspect tool on Adobe Content Authenticity (Beta)", describes "Inspect" ("a C2PA conforming validator product that can display and apply Content Credentials for various asset types"), not Verify. Its "Content details" section lists four subsections: "App or device used", "Recorded by", "Actions", "Ingredients" (plus an "AI-generated" note when the image was made with a generative tool). It says "Does not have an associated manifest store, Inspect displays the message No Content Credential." The word "assertion" appears only inside the sample JSON (`"label": "c2pa.actions.v2"`); the page says nothing about assertions with other labels. DERIVED: the documented panels have no place for a domain-labelled assertion; whether the product hides it was not tested. Whether Inspect is the same product as the Verify page was NOT established from these pages.
- The trust-lists page's "Verify tool" section (read in A26, T3 and T4) speaks only of known certificates.

## What a product would have to build

Its own display: read `activeManifest().assertions`, pick the entry with our label, show a receipt reference and verdict with the statement of what is and is not proved, and verify the receipt itself (the library does not). If the data must survive the library, store it as JSON or CBOR, not as binary; keep our label away from known base labels and from names ending in `.metadata`.

## Test that would confirm or kill this

In the project's terms: build (by C2PA Tool, outside this tick) one test manifest with a domain-labelled CBOR assertion carrying a 64-byte reference; read it with `Reader.fromBlob` in the testbed and record whether the label appears in `activeManifest().assertions`. Kill finding 2 if it does not. Then drop the same file onto the public Verify page and Inspect and record shown, hidden or flagged.

## Not verified

Nothing was run: finding 2 is from source. TypeScript type of `assertions`; the `crJson()` path; the legacy repository's components; the Verify page's behaviour and whether Inspect equals it; behaviour on a signed manifest whose third-party assertion is also listed in `created_assertions` (validation status); the two files downloaded and not read for a finding (`reader.ts` of c2pa-rs, testbed README).
