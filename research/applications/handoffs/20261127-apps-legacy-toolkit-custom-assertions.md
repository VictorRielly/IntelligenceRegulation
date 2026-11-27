# A37: what the legacy toolkit passes to the legacy components

Applications researcher tick, 2026-11-27 UTC (clock read 06:45Z at the start). Triage material, not a work order. Nothing was built or run. Follows A35 (`20261127-apps-legacy-components-custom-assertions.md`), which left the toolkit unread.

## Question

In the deprecated web repository, does a domain-labelled assertion reach `manifest.assertions.data`, and which fields does the older summary component's input hold?

## What was read, and how

Repository `contentauth/c2pa-js-legacy`, commit `c8c2912e2855c857277c0e1a6535a6db18e13c8e` (head resolved in A35). Raw text over HTTPS with python3 `urllib` and a generic User-Agent, no clone, no CLI client; each file saved in its own new directory and read as text; nothing executed. Base: `https://raw.githubusercontent.com/contentauth/c2pa-js-legacy/c8c2912e2855c857277c0e1a6535a6db18e13c8e/`. All four named paths existed at that commit on the first request (no tree listing, no probes). Ten page reads in all (budget 12), no web search:

1. `packages/toolkit/src/lib.rs` (4,986 bytes), 2. `packages/toolkit/src/manifest_store.rs` (1,544), 3. `packages/c2pa/src/createL2ManifestStore.ts` (4,052), 4. `packages/c2pa-wc/src/components/Popover/Popover.ts` (9,577), all four named by the item.
5. `packages/toolkit/Cargo.toml` (999), to find the Rust reader's pin. 6. `packages/c2pa/src/manifest.ts` (4,640). 7. `packages/c2pa/src/assertions.ts` (1,631). 8. `packages/c2pa/src/manifestStore.ts` (5,207): the three JavaScript files that sit between the toolkit and the components (6 and 7 were also read in A35; sizes equal).
9. `sdk/src/manifest.rs` (114,787) and 10. `sdk/src/manifest_store.rs` (26,007) of `contentauth/c2pa-rs` at the short revision the Cargo file names, `0a29852` (`https://raw.githubusercontent.com/contentauth/c2pa-rs/0a29852/...`). The short revision resolved; I did not expand it to a full commit hash.

## Findings

### 1. The toolkit does not select assertions; it serialises the whole Rust store (COUNTED)

- `lib.rs` 82-86: `struct AssetReport { manifest_store: c2pa::ManifestStore, cawg_json: String, }`. Lines 156-165 build it and serialise with `Serializer::new().serialize_maps_as_objects(true)`. Searching `lib.rs` and `manifest_store.rs` for "assertion" and "label" finds only `IdentityAssertion` (lines 30, 148), which feeds the separate `cawg_json` string, not the manifest.
- `manifest_store.rs` 18: `ManifestStore::from_bytes_async(mime_type, data, true)`; 32: `ManifestStore::from_manifest_and_asset_bytes_async(manifest_bytes, format, asset_bytes)`. No filtering, no label list.
- `Cargo.toml` 11: `c2pa = { git = "https://github.com/contentauth/c2pa-rs.git", rev = "0a29852", features = [..."v1_api", "file_io", "rust_native_crypto"], default-features = false }`; line 5 `version = "0.33.3-1"`.

### 2. In the pinned Rust reader, a CBOR or JSON assertion with an unknown label is copied into the list; binary and UUID boxes are dropped (COUNTED)

- `manifest.rs` 67: `#[derive(Debug, Default, Deserialize, Serialize)]`; 112-113: `#[serde(default = "default_vec::<ManifestAssertion>")]` / `assertions: Vec<ManifestAssertion>,`. No skip on serialisation.
- Catch-all arm at 759-781: `_ => {` / `// inject assertions for all other assertions`; `AssertionData::Cbor(_)` gives `ManifestAssertion::new(label, value)` (764), `AssertionData::Json(_)` the same with `.set_kind(ManifestAssertionKind::Json)` (771-773); then `// todo: support binary forms` (778) with `AssertionData::Binary(_x) => {}` and `AssertionData::Uuid(_, _) => {}` (779-780), which push nothing.
- The special arms before it are fixed labels only: actions (677), ingredient (720), the three hash labels (732), thumbnail (735), assertion metadata (745), names ending `.metadata` (752).
- `manifest_store.rs` 38: `#[derive(Debug, Serialize, Deserialize)]`; 47: `manifests: HashMap<String, Manifest>,`. The sync and async readers share one body (`manifest.rs` 569 `#[async_generic]`).

### 3. The JavaScript library hands that list to the components unfiltered (COUNTED, DERIVED)

- `manifestStore.ts` 65-78: `parseJsonTypeHints` rewrites only number wrappers. `manifest.ts` 160: `assertions: createAssertionAccessor(manifestData.assertions),`. `assertions.ts` 52-53: `data: sortedAssertions,` (sorted by `instance`, 48-50); `get` filters `data.label === label` (57).
- DERIVED: a domain-labelled assertion whose box is CBOR or JSON reaches `manifest.assertions.data` and `manifest.assertions.get('<its label>')`, with its decoded content. A binary or UUID box does not. Not run. The label written at `manifest.rs` 764 is `claim_assertion.label()` (673); whether a second instance of one label carries an index suffix there (`assertions.ts` 33 says `get` takes the label "without an index") was not read.

### 4. The older summary component's input holds twelve fixed fields (COUNTED)

`createL2ManifestStore.ts` 35-48, `L2ManifestStore`: `format`, `title`, `signature`, `claimGenerator`, `producer`, `socialAccounts`, `thumbnail`, `generativeInfo`, `web3`, `isBeta`, `error`, `validationStatus`. The builder (110-138) fills each from a selector or a literal field; the only direct label read is line 133, `isBeta: !!activeManifest.assertions.get('adobe.beta')?.[0]?.data.version,`. No field holds the assertion list or an arbitrary label. DERIVED: a custom assertion cannot reach this component's input through this function; an application must read `manifest.assertions` itself.

### 5. `Popover.ts` is not on the data path (COUNTED)

Search for "assertion" and "manifest" in the file: 0 matches. It is a positioning wrapper, `@customElement('cai-popover')` (43), with two slots, `<slot name="content"></slot>` (356) and `<slot name="trigger"></slot>` (361). An application's own panel could sit in its content slot; the component itself carries no manifest data.

### 6. A malformed assertion may remove the whole manifest, and the JavaScript side may then throw (DERIVED, not run)

`manifest.rs` 763 and 770: `let value = assertion.as_json_object()?;` (error passed up; `as_json_object` not read). `manifest_store.rs` 217-226: on `Err(e)` the manifest is not inserted and `validation_results.add_status(ValidationStatus::from_error(&e));` is called. `manifestStore.ts` 127: `data: toolkitManifests[toolkitActiveManifestId],` and 158 `createManifest(manifestData, ...)`, whose first use is `manifestData.ingredients.map` (`manifest.ts` 133), so a missing active manifest would raise a TypeError in the JavaScript library. The read would then fail instead of recording the status. This is an inference from lines in three files; it is the test below.

## What a product would have to build

An own panel that reads `manifest.assertions.get('<domain label>')` (legacy) or `activeManifest().assertions` (current library, A32); carry the receipt reference as JSON or CBOR, never as a binary box (finding 2); show the verdict and the statement of what is and is not proved; verify the receipt itself; guard the read against an exception for a store whose assertion is malformed.

## Test that would confirm or kill this

Build three small signed files outside this tick, each with a domain-labelled assertion: (a) JSON with a 64-byte reference, (b) a binary box, (c) invalid JSON. Read each with the legacy toolkit and library. Kill finding 3 if (a) is absent from `manifest.assertions.data`; kill finding 2's drop if (b) appears; for (c) record whether `manifests` lacks the active manifest, whether `validationStatus` lists an error, and whether `createManifestStore` throws. Render (a) with the older summary component and confirm nothing from it is shown (A35 finding 1).

## Not verified, not determined

- Nothing was built or run; every statement is a reading.
- `as_json_object`, `decode_data`, `claim_assertion.label()` and the `Assertion` type were not read; finding 6's first link rests on the `?` alone.
- The toolkit's TypeScript types (`@contentauth/toolkit`) were not read; whether the published packages equal this commit was not checked.
- The pin `0a29852` was fetched as a short revision; the full hash was not confirmed.
- The selectors that build the other eleven input fields, `lib/cawg`, and the remaining components were not read (A35's list stands).
- This is the deprecated repository; it says nothing about the current library or any hosted viewer.
