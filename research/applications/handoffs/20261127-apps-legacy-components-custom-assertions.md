# A35: do the standard's legacy web components render an assertion with an unknown label?

Applications researcher tick, 2026-11-27 UTC (clock read 02:44Z at the start). Triage material, not a work order. Nothing was built or run. Follows A32 (`20261127-apps-web-reader-custom-assertions.md`), which did not read the deprecated repository.

## Question

In the deprecated legacy web repository, does any viewer component render an assertion whose label it does not know, or do the components show only fixed labels? Report file, line and version.

## What was read, and how

Pinned source: repository `contentauth/c2pa-js-legacy`, default branch `main`, head resolved once through the public API: commit `c8c2912e2855c857277c0e1a6535a6db18e13c8e` ("Bump versions [skip ci]", committer date 2025-11-07T18:33:42Z). The repository record says `archived: False`, `pushed_at` 2025-11-07T18:34:12Z, description "JavaScript SDK for displaying and validating C2PA data" (the new repository's README, read in A32, calls this one deprecated).

Method: python3 `urllib`, generic User-Agent, no clone, no CLI client. Each raw file saved in its own new directory and read as text with `python3 -I`; nothing executed. Files read (all at the commit above, base `https://raw.githubusercontent.com/contentauth/c2pa-js-legacy/c8c2912e2855c857277c0e1a6535a6db18e13c8e/`; sizes in bytes equal the sizes in the tree listing):

1. `packages/c2pa-wc/package.json` (3,400)
2. `packages/c2pa-wc/src/getManifestSummaryData.ts` (3,856)
3. `packages/c2pa-wc/src/components/ManifestSummary/ManifestSummary.ts` (9,404)
4. `packages/c2pa-wc/src/components/ManifestSummaryV2/ManifestSummaryV2.ts` (11,508)
5. `packages/c2pa-wc/src/components/MinimumViableProvenance/MinimumViableProvenance.ts` (3,479)
6. `packages/c2pa/src/assertions.ts` (1,631)
7. `packages/c2pa/src/manifest.ts` (4,640)
8. `packages/c2pa/package.json` (2,617)
9. `packages/c2pa/src/selectors/selectEditsAndActivity.ts` (10,445), searched for label use, not read through

Plus three API reads: repository record, head commit, recursive tree listing (`https://api.github.com/repos/contentauth/c2pa-js-legacy/git/trees/c8c2912e2855c857277c0e1a6535a6db18e13c8e?recursive=1`, `truncated: False`, 495 entries). Total 12, the budget. No web search; no address was guessed (every path came from the tree listing; zero HEAD probes).

Versions: `packages/c2pa-wc/package.json` line 3 `"version": "0.14.17"`; `packages/c2pa/package.json` line 3 `"version": "0.30.17"`.

## Findings

### 1. The two summary components render a fixed set of fields, none of them a list of assertions (COUNTED)

- Older component, `ManifestSummary.ts` lines 205-218, a `dataSelectors` object with six keys: `contentSummary`, `producedBy`, `producedWith`, `socialMedia`, `aiToolUsed`, `web3`. Lines 220-291 render, in turn, `cai-minimum-viable-provenance` and then, only if the matching value exists, `cai-content-summary`, `cai-produced-by`, `cai-produced-with`, `cai-social-media`, `cai-ai-tool`, `cai-web3`. No line loops over assertions or labels. The input is typed `L2ManifestStore` (line 170), a pre-digested object, not the raw manifest.
- Newer component, `ManifestSummaryV2.ts`: input type `ManifestSummaryStore` (line 213). Lines 248-259 read `recorder`, `name`, `nameVerifier`, `socialAccounts`, `unrecordedChanges`, `doNotTrain`, `error`; lines 263-268 map four tags (`ai`, `no-ai`, `camera-captured`, `more-info`) to strings; line 277 the header is the literal `Content Credentials`. `getManifestSummaryData.ts` lines 21-30 define exactly those fields. Nothing else is rendered.
- `getManifestSummaryData.ts` lines 133-136 and 142-145: the tags `camera-captured` and `more-info` sit behind `if (false) {` with "TODO: add camera-captured" and "TODO: add more-info"; only `ai` (line 130) and `no-ai` (line 139) can be produced. The same file reads two social-identity types by fixed string (`'cawg.social_media'`, line 82; `'cawg.document_verification'`, line 103).
- `MinimumViableProvenance.ts` lines 96-119: shows only the signer's name and signature date.

DERIVED from these lines: in the three components read, an assertion with a label the code does not name is not shown, because no component receives or iterates the assertion list. Not run: no manifest was rendered.

### 2. The raw list exists on the manifest object, but the reading code asks for four fixed labels (COUNTED)

- `manifest.ts` line 98 `assertions: AssertionAccessor;`, with the comment at line 96: "Interface providing access to assertions contained within this manifest". Line 160: `assertions: createAssertionAccessor(manifestData.assertions),`.
- `assertions.ts` line 27: "Raw assertion data as returned by the WASM binary", line 29 `data: Assertion[];`; line 32: "Convenience method that returns an array of all assertions matching a given label, sorted by their index value"; lines 55-58 `get` filters by `data.label === label`. Line 12 declares `export interface ExtendedAssertions {}`, empty, the hook for typing more labels.
- Searched with a pattern (`assertions.get`, `assertions.data`, `.assertions`) in `getManifestSummaryData.ts`, the three components, `manifest.ts` and `selectEditsAndActivity.ts`: the only uses of `assertions.get` are in `selectEditsAndActivity.ts`, lines 166-170:

```
manifest.assertions.get('com.adobe.dictionary')[0] ??
manifest.assertions.get('adobe.dictionary')[0];
const [actionsV2] = manifest.assertions.get('c2pa.actions.v2');
const [actionsV1] = manifest.assertions.get('c2pa.actions');
```

(two vendor-dictionary labels and the two action labels). The same search found `.assertions` elsewhere only at `manifest.ts` line 160 and no use of `assertions.data` in those files.

DERIVED: a developer can read a custom assertion through `manifest.assertions.get('<our label>')` or `.data`, but the shipped components do not.

### 3. A place for an application's own display exists (COUNTED)

`ManifestSummary.ts` lines 285-290: a `<slot ... name="post" ...>` inside the content container, with `slotchange` handling. DERIVED: an application can insert its own element under the standard sections without editing the component. Not run.

## What a product would have to build

Its own panel: read `manifest.assertions.get('<our domain label>')` in the legacy library (or `activeManifest().assertions` in the current library, A32), show the receipt reference, the verdict and the statement of what is and is not proved, and verify the receipt itself. A viewer user would not otherwise see it. Place it in the `post` slot if the summary component is used.

## Test that would confirm or kill this

Build one manifest (outside this tick) with a domain-labelled JSON assertion carrying a 64-byte reference. (a) Read it with the legacy library and check that `manifest.assertions.data` holds the label; kill the "the raw list exists" part of finding 2 if not. (b) Render it with `cai-manifest-summary` and `cai-manifest-summary-v2` and check that nothing from the assertion appears; kill finding 1 if any text appears. (c) Put a test element in the `post` slot and check it appears.

## Not verified, not determined

- Whether the legacy toolkit hands the library a third-party assertion at all: `packages/toolkit/src/lib.rs` and `manifest_store.rs` (and the Rust reader version they pin) were not read. Finding 2 assumes the list is complete; `manifestData.assertions` is typed in a package I did not open.
- Components not read: `Popover`, `ContentSummary`, `ProducedBy`, `ProducedWith`, `SocialMedia`, `Web3`, `AIToolUsed`, `HeaderSection`, `PanelSection`, `Thumbnail` and the badge file (`src/badge.ts`), nor `createL2ManifestStore.ts`, which builds the older component's input and so decides its fields. The tree has 16 component directories under `packages/c2pa-wc/src/components/`; I read three. The claim "no component renders it" is therefore for those three and not for the library.
- Selectors other than `selectEditsAndActivity.ts` were not read (`selectGenerativeInfo`, `selectProducer`, `selectSocialAccounts`, `web3Info`, `selectDoNotTrain`, `isHandmade`); I assume, without reading, that they too use fixed labels.
- `selectEditsAndActivity.ts` was searched, not read in full.
- The React package, the examples and the stories were not read.
- Nothing was built or run; no hosted viewer was tried. This is the deprecated repository, so it says nothing about what a current hosted viewer shows.
