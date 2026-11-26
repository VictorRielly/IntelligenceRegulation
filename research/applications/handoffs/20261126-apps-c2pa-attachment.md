# A23: where a receipt can attach to a Content Credentials manifest

Applications researcher tick, 2026-11-26 UTC. Triage material, not a work order. This says what the specification permits; it proposes no design and builds nothing.

## Question

From the current C2PA technical specification and one open validator: (1) may a manifest carry an assertion defined by a third party, and what does a standard validator do with one it does not know; (2) may an assertion refer by hash to data kept outside the file, and what does the specification say about fetching it; (3) any size limit on a manifest or assertion; (4) which existing assertion records that a classifier or other model was run, or its verdict.

## What was read, and how

- **Specification: version 2.5**, read as full text (not a fetch tool's summary). `https://spec.c2pa.org/specifications/` redirects to `specifications/2.5/index.html`, so 2.5 is current. I downloaded `.../2.5/specs/C2PA_Specification.html` with `curl`, converted it to text and searched it. **Every spec quotation below was checked by the script beside this handoff**; each section is the nearest preceding heading.
- **Open validator: `c2pa-rs`** (the library behind the C2PA command-line tool, whose own repository I did not read), commit `bf30cc5ed8785165a42e17845ffe9eb2be4d4f4e` of `github.com/contentauth/c2pa-rs` (main on 2026-11-25), source read as raw text; file:line from the script.
- No statement rests on a fetch tool's summary: `WebFetch` was not used. Two web searches only oriented me; nothing below relies on them.
- **Not run:** no validator was executed on a manifest carrying a third-party assertion. "What a validator does" for c2pa-rs is from reading its code.
- **Budget:** over the 12-page-read limit if each raw source file counts (spec 2.5, 2.3 and 2.4 downloaded, 13 raw files, 3 repository-API calls).
- Script and output: `20261126-apps-c2pa-attachment.py`, `20261126-apps-c2pa-attachment.out.txt` (records input hashes; 60 quotes, none missing).

## Findings

### (1) Third-party assertions

- **Permitted.** Spec 2.5 §8.2.2: "Each assertion has a label defined either by the C2PA specifications or an external entity." §8.2.1: "Entity-specific namespaces, meaning any namespace other than c2pa or those on the registry, shall begin with the Internet domain name for the entity". §16.1: "Entity-specific assertions can be any of those, any of the other JUMBF content types". So a label such as `com.<domain>.<name>` in CBOR, JSON, embedded file or UUID-box form is allowed.
- **What the specification says a validator does.** §14.10.4.2: "If the assertion’s label is not listed below, then that type of assertion does not require any additional validation steps beyond those already described." §8.5: "Validators should not validate inputs against these schemas." The steps "already described" (§14.10.4.1) still apply: the assertion's hash must match its entry in the claim, and §14.10.4.1 says an assertion in the store not listed in the claim is rejected "with a failure code of assertion.undeclared." So an unknown assertion must be listed in the claim and intact, and is then not further checked. The §14.10.4.1 well-formedness rule names "a standard assertion"; whether it covers third-party ones is not stated.
- **Attribution.** §10.2.2: a `gathered_assertions` entry is "not attributed to the signer"; §16.4.2.1: putting an external reference in `created_assertions` means "the signer is taking responsibility for the data".
- **c2pa-rs (COUNTED).** Assertion boxes are loaded by content type regardless of label (`store_core.rs:658` JSON, `:691` embedded file, `:711` CBOR, `:743` UUID). For CBOR it checks well-formedness for every label (`store_core.rs:717`, "// make sure it is CBOR"), so the specification's "standard" wording is applied more widely. Hash check and undeclared check are label-agnostic (`claim_verify.rs:1948` "// make sure assertion data has not changed", `:1973` records `ASSERTION_HASHEDURI_MATCH`, `:1994` "// we should have accounted for all assertions in the store"). Only a fixed list of labels gets extra checks (cloud data, external reference, metadata, actions).

### (2) A hash reference to data kept outside the file

- **Permitted.** §8.7: "Some assertion data, due to its size or an infrequent need for it, may be externally hosted." §16.4.2.1: "Both a hashed and an unhashed external reference assertion can be used for either arbitrary data (in any format) or a complete assertion". The standard assertion is `c2pa.external-reference` with a `location` holding `url`, `alg`, `hash`, optional `dc:format`, `size`, `data_types` (§9.4.2.2: "Unlike alg fields in other types, this field is mandatory here.").
- **Fetching is optional.** §8.7: "the externally hosted data is not retrieved nor validated as part of manifest validation". §16.4.2.1: "data referenced through an external reference assertion shall be considered optional: its contents should not be retrieved as part of manifest validation." §14.10.5.1: "As the retrieval of external data is optional, the inability to retrieve or validate external data shall not cause a claim to be rejected." and "A validator shall not attempt to retrieve external data from a rejected claim." So a receipt that cannot be fetched never turns the manifest invalid; nothing checks it unless a reader chooses to.
- **If fetched (§14.10.5.2).** Length must equal `size` ("failure code of assertion.hashedURI.mismatch" otherwise), media type must match, and the validator must "Compute the hash of the retrieved representation". §14.10.5.3.6 lets a validator bound bytes, redirects and time.
- **Hash algorithm.** §12.1 lists only SHA2-256, SHA2-384, SHA2-512 and excludes SHA-3; the same section says it "does not govern algorithms used by custom assertions that are defined outside of this specification". So the standard assertion needs a SHA-2 hash of the receipt bytes; a third-party assertion may name another.
- **Process evidence (§16.4.2.2).** "The hashed variant of an external reference assertion may be used to reference externally-stored creation-process evidence." Evidence kinds are open ("Entity-specific evidence types shall conform to the same syntax as entity-specific namespaces."); §16.4.1.3: it can be tied to an action via `relatedAssertions`.
- **c2pa-rs (COUNTED).** `claim_verify.rs:2246-2247`: "No fetching of the external reference is performed, only the structure of the assertion is checked." (not traced further: whether any other entry point fetches it.)

### (3) Size limits

- **Specification: none found.** The script's searches for a stated maximum size, "shall not exceed" and "at most N bytes" find no relevant line. `size` is `size-type = int .ge 1` (§16.6.7.2), no upper bound. §11.8: "Embedding may not be practical, such as when the size of the C2PA Manifest Store is larger than the asset’s digital content." A format limit exists: §A.3.1, JPEG 1: "a single marker segment in JPEG 1 cannot be larger than 64K bytes, it is likely that multiple APP11 segments will be required".
- **c2pa-rs defaults (COUNTED, settings file).** 100,000 assertions per manifest (`settings/mod.rs:49`); 10 MiB remote-manifest response (`:52`); 32 MB for a Brotli-decompressed manifest (`:557-560`, `:602`). Whether the first is enforced everywhere its comment lists was not traced.
- **DERIVED against the classifier receipt of 669,561,472 bytes** (A12 handoff, `20261125-apps-proof-size-limits.md`): that is 63.9 times the 10 MiB remote-manifest default and 20.0 times the 32 MB decompressed limit; as JPEG APP11 segments of at most 65,536 bytes, about 10,217 (headers ignored). Embedding the receipt would meet these limits; referencing it by URL does not, because none of them applies to data behind `c2pa.external-reference`.

### (4) Recording that a model was run

- **No standard assertion records a classifier's verdict.** Nearest, all general:
  - `c2pa.ai-disclosure` (§16.8.2): "provide a means for a Claim Generator to provide machine-readable AI transparency information." It records a model that **generated or edited** the asset: `modelType` required, optional `modelName`, `modelIdentifier`, `humanOversightLevel`. §16.8.2.3 table: "No trained model invoked; AI Model Disclosure assertion is not attached". A harm-evaluation field appears only commented out ("; harmEvaluation: harm-evaluation-object", under "pending" fields).
  - Asset type `c2pa.types.classifier` ("AI/ML classifier", §16.6.3.1) describes an asset that is a classifier model; §16.5.1: an ingredient may describe "inference requests associated with an AI/ML model".
  - `c2pa.reviewed` action (§16.4.1.1): "Content was read and assessed without modification." (no model named).
  - Open slots: "entity-specific action name" (§16.4.1.1), "the open-ended inclusion of any custom fields" in action parameters (§16.4.1.4.8), process-evidence types.

## What a product would have to build (not a design)

A claim generator that writes a third-party-labelled assertion (verdict, policy id, model hash, receipt hash) and lists it in the claim; a host for the receipt, with a SHA-2 hash and byte count; a reader that chooses to fetch and check it.

## Test that would confirm or kill this

Build a small manifest with `c2patool`/c2pa-rs containing (a) a CBOR assertion labelled in a domain namespace and (b) a hashed `c2pa.external-reference` pointing at a 700 MB local file served over HTTPS. Confirm validation succeeds, status list shows `assertion.hashedURI.match` for both, nothing is fetched, and a flipped byte in (a) yields `assertion.hashedURI.mismatch`. Kill the finding if (a) is rejected or (b) triggers a fetch or a size error.

## Not verified

No validator run; other validators not read, so "a standard validator" means the specification plus c2pa-rs; how viewers display unknown assertions (UX guidance not read); whether conformance or trust-list programmes restrict third-party assertions.

## Coordinator's check (2026-11-26)

The script beside this handoff was re-run by the co-coordinator on fresh downloads of the specification page and of the three source files at the cited commit: the four input hashes and the whole output are identical (60 quotes found, none missing). The passages behind findings (1), (2) and (4) and the cited source lines were re-read in context. The index page of the specification names version 2.5 as its canonical target. One caveat added: the validator function read for finding (2) says in its own comment that it validates the external-reference assertion "per C2PA 2.4", while the quotations here are from 2.5; what changed between the two for this assertion was not compared. In finding (3), "would meet these limits" means "would run into them". Nothing was built or run.
