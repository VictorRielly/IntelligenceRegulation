# Coordinator's check of A39 (a malformed custom assertion in the older reader and the legacy library)

By Claude (co-coordinator), 2026-11-27. Checks `20261127-apps-legacy-malformed-assertion.md`. Reading of public source at two pinned commits; nothing was built or run.

## What was done

- Own downloads of the ten source files the handoff reads, each into its own new directory, with a generic User-Agent and nothing else sent. All ten have the byte lengths and SHA-256 values in the handoff's table (c2pa-rs at `0a29852b0546596972c7105a7a510b12e050dc67`, c2pa-js-legacy at `c8c2912e2855c857277c0e1a6535a6db18e13c8e`).
- Three further files of the legacy library that the handoff relied on but did not read: `packages/c2pa/src/manifestStore.ts`, `manifest.ts` and `ingredient.ts`, same commit. The first two have the hashes of the copies made for the check of A37.
- `20261127-apps-legacy-malformed-assertion-recheck.py` (run with `python3 -I` and the download directory), output `-recheck.out.txt`: 106 checks, none failed. The main passages were also read by eye.
- The handoff's own check script is outside the repository (the handoff names a path on the work machine). The script here replaces it for a reader of the repository.

## Confirmed

- **The log records and goes on by default** (`status_tracker/mod.rs` 23-24, 97-98, 190-192; `log_item.rs` 235-238).
- **Both routes of the toolkit build that default log** (toolkit `manifest_store.rs` 18, 32; reader `manifest_store.rs` 259, 264, 453-454) and hand it down (`store.rs` 4355, 4143, 3968). Outside test modules the stopping log is built at five lines of `store.rs` (514, 580, 2688, 2870, 4674), in five functions that are not on either route, and at `manifest_store.rs` 246 in `from_manifest`, which starts from a manifest and not from a file.
- **A box that does not parse is recorded, and the assertion is still stored**: JSON `store.rs` 799-811, CBOR 851-863, the loader 1370-1378. **A JSON box that is not UTF-8 returns an error before the log is asked** (`store.rs` 796; `assertion.rs` 441-447) and the loader returns it (1381-1391). The CBOR arm has no such step (`assertion.rs` 430).
- **The conversion then fails for that manifest only**: `as_json_object` returns an error (`assertion.rs` 331-346), the catch-all arm passes it up with `?` (`manifest.rs` 763, 770), and both builders put a manifest in the list in their `Ok` arm only and add a status in the `Err` arm (`manifest_store.rs` 180-188, 217-225; the two insertions are the only ones). The active label was set before the loop (169, 206).
- **The outer read call** catches (`c2pa.ts` 236-247) and throws again everything except one named kind and three patterns (291-295, 318-330).
- **The types** (`types/index.ts` 27-29, 50, 107, 113-123, 171, 312).

One line number: the handoff puts the test module of `store.rs` at 4960; the module opens at 4961 (4960 is its attribute line). Nothing depends on it.

## What this check adds: the step in the legacy library

The handoff says that, with the manifest left out, the library "reads a field of a missing value", on the strength of an earlier note, and marks it not re-read. Read here:

- `createManifestStore` builds the manifests first (`manifestStore.ts` 89-93). `createManifests` starts from the active label: `data: toolkitManifests[toolkitActiveManifestId]` (127). If the list lacks that manifest, the value is `undefined`.
- The walk over ingredients is guarded (`currentManifest?.ingredients?.forEach`, 139), so it goes on. Line 158 then calls `createManifest(manifestData, manifests, cawgData)`, and `manifest.ts` 133 reads `manifestData.ingredients.map(` with no test before it (128-134). For `undefined` that is a TypeError by the language's rule [DERIVED from the text; not run].
- The call is inside the `try` of `read` (`c2pa.ts` 243), so `handleErrors` receives the error. Its name is neither the remote-manifest name nor any of the three ignored patterns, so line 330 throws it again and `read` rejects.

**So, if the Rust side returns a store at all, a malformed custom box in the active manifest makes the legacy library's `read` reject with a TypeError.** The page gets an exception. It does not get "no credentials" (the `null` store of the ignored kinds), and it does not get a store with one manifest missing.

**A manifest missing for an ingredient is treated differently.** Line 141 tests the list and line 147 only writes a debug line, so that manifest is not walked; `createManifest` passes `undefined` for it (`manifest.ts` 137) and `createIngredient` stores `manifest: manifest ?? null` (`ingredient.ts` 91, 103). The ingredient is built without its manifest and nothing throws at these lines.

This answers the first two questions of queue item A42; the item is narrowed to what is left (below).

## Not determined

- Whether the Rust side returns a store for a signed claim whose box does not parse: `verify_store_async` is awaited with `?` (`store.rs` 4358-4365) and was not read (queue item A43).
- Whether the status recorded for the box reaches the serialised store's status lists (A43).
- The error name a JSON box that is not UTF-8 reaches `handleErrors` with, and whether it can be one of the three ignored names (the toolkit's `error.rs` and the Rust conversions were not read; what is left of A42).
- Nothing was run. No file with such a box was read by either library.

## What it means for a product

- The rule from A38 holds for the older reader too: a custom record that carries a proof reference must be well-formed CBOR or UTF-8 JSON, and must be read back with the pinned readers before release.
- With the legacy library the likely result of a bad record in the active manifest is an error on the page, not a partial display. A record of ours has to be tested against both libraries for as long as the older one is in use.
- This is two source trees at two commits. It says nothing about what any service does with such a file.
