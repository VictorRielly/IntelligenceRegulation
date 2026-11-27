# A36: does the standard's open Rust library's crJSON writer output a custom assertion with its data?

Applications researcher tick, 2026-11-27 UTC (clock read 04:14Z at the start). Triage material, not a work order. Nothing was built or run. Follows A32 (`20261127-apps-web-reader-custom-assertions.md`), which read the web reader's own conversion, and A35.

## Question

At the tag `c2pa-v0.92.2` of the standard's open Rust library, does the writer behind `Reader::crjson()` emit a domain-labelled CBOR assertion with its data, or as an empty object? File and line for each statement; say whether read as text.

## What was read, and how

Pin: tag `c2pa-v0.92.2`, an annotated tag; an earlier item resolved it to commit `d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b`. The recursive tree listing of that commit (`https://api.github.com/repos/contentauth/c2pa-rs/git/trees/d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b?recursive=1`, `truncated: false`, 778 entries) returned a top-level `sha` equal to that commit hash. Every path below came from that listing (zero HEAD probes, zero guessed addresses). Method: python3 `urllib` with a generic User-Agent, no clone, no CLI client; each file saved in its own empty directory and read as text; nothing executed. Base address: `https://raw.githubusercontent.com/contentauth/c2pa-rs/d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b/`. Byte sizes of all six files equal the sizes in the tree listing.

1. `sdk/src/crjson.rs` (54,327 bytes), read lines 170-298, 350-464, 683-768, 926-949 and searched by pattern
2. `sdk/src/reader.rs` (74,723), lines 585-613 and a pattern search for `crjson`
3. `sdk/src/assertion.rs` (25,265), lines 326-371, 373-449, 708-738
4. `sdk/src/utils/json_b64.rs` (8,805), lines 1-190
5. `sdk/src/store/store_core.rs` (86,385), lines 630-775
6. `sdk/tests/crjson/created_gathered.rs` (8,475), lines 28-97

Total: 6 file reads plus the one tree call. No web search.

## What exists at the tag

The writer exists under the name the item gives. `Reader::crjson()` is `sdk/src/reader.rs` line 603; it calls `crjson_checked()` (line 610), which calls `to_crjson_value()` (line 595), which calls `crate::crjson::from_reader(self)` (line 596). The writer is `sdk/src/crjson.rs`, `pub fn from_reader` (line 213). The tag has no other crJSON writer file; the tree lists `sdk/src/crjson.rs`, `sdk/tests/crjson/` (five test files), `sdk/tests/crjson_tests.rs` and `sdk/tests/fixtures/schemas/crJSON-schema.json` (the schema file was not read).

## Findings

### 1. A CBOR or JSON custom assertion comes out with its data (COUNTED, read as text)

- `crjson.rs` 352-366, `build_assertions`: "for ca in claim.claim_assertion_store() {" takes every stored assertion of the claim; `let key = ca.label();` (line 359) is the output key, and the comment at 357 says "ClaimAssertion::label() already encodes the instance suffix as `base__N`". The value is inserted at 363-364 if `claim_assertion_to_value` returns `Some`.
- `crjson.rs` 462, the catch-all arm of `claim_assertion_to_value`: `_ => Ok(assertion.as_json_object().ok().map(fix_hash_encoding)),`. The doc comment at 413-414: "Everything else is decoded via [`Assertion::as_json_object`] and passed through [`fix_hash_encoding`] to convert byte arrays to base64." There is no label test before this arm except for ingredient labels (line 424) and the thumbnail prefixes (440-452, binary data only).
- `assertion.rs` 338-342, CBOR arm of `as_json_object`: it decodes the whole CBOR value and returns `Ok(cbor_to_json_b64(value))`; the JSON arm (335-336) is `serde_json::from_str(x)`.
- `json_b64.rs` 73-78: a CBOR map becomes a JSON object with every entry; 71 text stays text; 66 integers stay numbers.

DERIVED: a domain-labelled assertion whose box is CBOR or JSON appears in `manifests[].assertions` under its own label with its decoded content. It is an empty object only if the stored map is itself empty. Not run: no manifest was written or read.

### 2. Binary and UUID boxes are not dropped here; they become a reference object (COUNTED)

`crjson.rs` 434-461: for binary or UUID data the value is `{"format": ..., "identifier": ..., "hash": ...}` (456-460), with `ca.hash()` base64-wrapped; the content is not included. This differs from the web reader in A32 (binary and UUID dropped). Which box type a custom assertion has is fixed when it is read: `store_core.rs` 657-663 JSON box, 691-700 embedded-file box (binary), 711-715 CBOR box, 743-748 UUID box.

### 3. Some assertions are omitted entirely (COUNTED, with a gap)

Line 462 uses `.ok()`: if `as_json_object` fails, the value is `None`, and `build_assertions` (363-365) then inserts nothing, so the label is absent from the output, not an empty object. For a CBOR box that does not parse, `store_core.rs` 718-731 logs an `ASSERTION_CBOR_INVALID` failure through `.failure(validation_log, ...)?`; whether that `?` aborts loading the manifest depends on the log's behaviour, which I did not read.

### 4. The writer rewrites some field names and values in any assertion (COUNTED)

`fix_hash_encoding` (`crjson.rs` 690-768) runs on every value of finding 1 and recurses (743-745):
- an object key named `hash`, `pad` or `pad2` whose value is an array of integers becomes a base64 string (701-716);
- "Ensure hash-bearing objects also carry a (possibly empty) pad field." (718): any object with a `hash` key and no `pad` gets a `pad` added (719-721);
- a `signature` value that is a string decoding as a marked base64 byte string, or an integer array, is passed to `decode_cawg_signature` and replaced by its result or by base64 (723-740);
- an `icon` object is cut down to `url`, `hash`, `alg` (748-760);
- the key `schema.org.SoftwareApplication.operatingSystem` is renamed `operating_system` (694-699).

Value conversions (`json_b64.rs`): byte strings become `b64'<base64>'` strings (line 70; doc 55-59 "Byte strings become `b64'<base64>'`-wrapped strings rather than JSON number arrays. Tags are unwrapped, non-finite floats become null, and non-text map keys are stringified. This is not a lossless mapping of arbitrary CBOR maps."). Line 15: "Conversion uses `c2pa_cbor` and inherits its supported integer range." A test at lines 168-179 shows integers `1u64 << 63` and `u64::MAX` are errors in the writing direction; I did not read the reading direction's range.

### 5. The whole document can be reduced to `{}`, but not by a custom assertion of finding 1 (COUNTED/DERIVED)

`reader.rs` 603-605: `self.crjson_checked().unwrap_or_else(|_| "{}".to_string())`; `crjson_checked` is the variant that returns the error (610). The only `?` on assertion values in the path is `claim_assertion_to_value(...)?` (363); in `claim_assertion_to_value` an error is returned only for an ingredient label (427, `JsonError`), so a custom-labelled CBOR, JSON, binary or UUID assertion cannot raise it (DERIVED from 415-464). Other errors from `build_document` (233-266) were not traced.

### 6. Gathered assertions of another claim (COUNTED)

`crjson.rs` 370-402: a version-2 "gathered" assertion stored in another claim is resolved and converted the same way (383); if it cannot be resolved it appears as `{"identifier": ..., "hash": ...}` (393-398), without data.

### 7. The library's own test shows presence, not content (COUNTED)

`sdk/tests/crjson/created_gathered.rs` 34-58 builds JSON assertions labelled `org.test.gathered`, `org.test.created`, `org.test.regular`, and lines 80-82 only check `obj.contains_key(...)` for the three labels. The other four test files in that directory were not read, so I cannot say whether any test compares a custom assertion's content.

## What a product would have to build

Put the reference, verdict and statement in a CBOR or JSON assertion under its own domain label, never binary or UUID. Keep those field names clear of `hash`, `pad`, `pad2`, `signature` and `icon`, or accept the rewriting of finding 4, and expect any byte string to come back as a `b64'..'` string. A reader reading crJSON then finds it under `manifests[].assertions["<label>"]`; the web reader of A32 returns CBOR and JSON data too, the legacy components of A35 do not show it.

## Test that would confirm or kill this

Outside this tick: sign a manifest with one CBOR assertion (a text field, an integer, a byte string, a field named `hash` holding text) and one JSON assertion, plus one binary one; call `crjson()`. Kill finding 1 if the text field is absent or the object is `{}`; confirm finding 4 if the `hash` object gains a `pad`; confirm finding 2 if the binary one shows only `format`, `identifier`, `hash`. Add a deliberately malformed CBOR box and check whether the label is missing (finding 3).

## Not verified, not determined

- Nothing was built or run; every statement is from source text, none from an actual crJSON output.
- Not read: `decode_cawg_signature` and `decode_b64_wrapped`; the `c2pa_cbor` crate; `build_claim`, signature and validation code in `crjson.rs`; the other four crJSON test files and `crjson_tests.rs`; the crJSON schema and whether it accepts an unknown label's value; the builder's code that writes a custom assertion; other `Reader` methods (`json`, `to_json_value`).
- Whether an invalid CBOR box aborts the whole read (finding 3) and which other errors turn the document into `{}` (finding 5) are not determined.
- This is one tag; later versions may differ.
