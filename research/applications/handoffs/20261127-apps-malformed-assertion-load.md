# A38: does a malformed custom assertion stop the library's read?

Applications researcher, 2026-11-27 (UTC). Triage material, not a work order.

## Question

In c2pa-rs tag `c2pa-v0.92.2` (commit `d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b`): when a CBOR or JSON box in a
domain-labelled assertion is invalid, does loading abort or only record a status? The coordinator's note on the
queue item already answered the default-log case. This tick does the four points it left: which reader logs reach the
store's loading call; the earlier `?` at `store_core.rs:663`; the stop-on-first-error log at `store_core.rs:1924`; and
the other JSON route (`manifest.rs`, item A32).

## What was read, and how

Every file was fetched unauthenticated from the public raw address at the commit above (paths from the recursive tree
listing at that commit; the listing sizes equal the fetched sizes), stored one per new directory, and read as text with
`python3 -I`. Nothing was executed, built or run. 12 page reads (the budget), no web search.

| File (path at the commit) | Bytes | SHA-256 |
|---|---|---|
| tree listing (api, recursive) | 193822 | 75964f0d776ca730a153d5508d1d02b093737fc4080d1250c729c416c11c7607 |
| `sdk/src/store/store_core.rs` | 86385 | 971165e2d2f75256b394c13e59e125199a6531522a5b776b89daea4b01797c0d |
| `sdk/src/store/store_io.rs` | 58633 | 132fc603d472141248131e05bfa940e73aedba5cdb2fa68c72aadccb56bfc1a4 |
| `sdk/src/store/mod.rs` | 827 | 3818bdde154774dd468c04402fa81c44057dfa265ba6446289873cd906f157e3 |
| `sdk/src/status_tracker/mod.rs` | 9891 | 4722fd3a4c5046dc7223affe53ee7065f8c2b92126999e713e5303eb6d7e3ec3 |
| `sdk/src/status_tracker/log_item.rs` | 16379 | 80fc020ec3ffe2e0eea154ad5bafa79de922441eaddb66e7b28d107c063a9100 |
| `sdk/src/reader.rs` | 74723 | 25ba2537ae86244aeb1cb75e133a66fff93f402e30e276f11d6d3ad1b5b8e6ec |
| `sdk/src/manifest.rs` | 75828 | c15ac6503bf8e1c9bbfef75cba1beac84bf20239d9fdab2fb225d7c15389e423 |
| `sdk/src/assertion.rs` | 25265 | 5be06a9400ba5bdbe71121633f0c43eaf58f0313ff60abc7fb76788c193f10c1 |
| `sdk/src/crjson.rs` | 54327 | 08862e14eacfb8c72fe95d71c2c9ddc1e2d4735d2c8606a549e893d7ea3e1ada |
| `sdk/src/builder.rs` (searched by text only) | 535729 | 0e7d6b8ba7019134f5a57af120ba64f2548c6859e7955e7dc1cfc3467d8ea7e9 |
| `sdk/src/claim/claim_core.rs` (searched by text only) | 94523 | e771a7da9355136f4b989b608c7dc72634ef4e898f80df5d3da3286a25a76b5c |

Line numbers below are those of the fetched files. [COUNTED] throughout.

## Findings

**1. What the log does (confirms the note).** `status_tracker/mod.rs` 105-108: `match self.error_behavior {
ErrorBehavior::StopOnFirstError => Err(err), ErrorBehavior::ContinueWhenPossible => Ok(err), }`. `log_item.rs` 256:
`pub fn failure<E: Debug>(mut self, tracker: &mut StatusTracker, err: E) -> Result<E, E>` ends `tracker.add_error(self,
err)` (259). Default: `mod.rs` 21 `#[derive(Debug, Default)]` on `StatusTracker`; 196-197 `#[default]
ContinueWhenPossible`. So `...failure(log, e)?;` is a no-op beyond recording when the log is the default.

**2. Which reader logs reach loading.** `reader.rs` has no `ErrorBehavior` and builds `StatusTracker::default()` at
225, 284, 297, 367, 413, 484, 973, 1051, 1301. Six reach the loading call:

- 225 (`with_stream`) -> `Store::from_stream` (236); 284 and 297 (`with_file`) -> `from_stream` (286) and
  `from_manifest_data_and_stream` (299); 367 -> `from_manifest_data_and_stream` (370); 413 -> `load_fragment_from_stream`
  (416); 484 -> `load_from_file_and_fragments` (494).
- Each lands in `Store::from_jumbf_with_context`: `store_io.rs` 1315 (via 1242 and 1280), 1351, 1400. That calls
  `from_jumbf_impl` (`store_core.rs` 988), which calls `get_assertion_from_jumbf_store` (1295) with the same log.
- Not loading: 973 (`post_validate`), 1051 (inside `walk_manifest`, 1003), 1301 (test module, which starts at 1223).

**3. The `?` at 663 (JSON box).** `store_core.rs` 663: `let assertion = Assertion::from_data_json(&raw_label,
json_box.json())?;`. It runs before the validity check (666). `assertion.rs` 437-442: `from_data_json` returns an error
only when `String::from_utf8(...)` fails (`BinaryDataNotUtf8`); otherwise `Ok` (444-448). That error does not go through
the log: it returns from the function whatever the log's setting. Caller `store_core.rs` 1305-1315: `Err(e) => {` ...
`return Err(e);`, and `reader.rs` 239 `}?;`, so a JSON box that is not UTF-8 makes the whole read fail with no Reader.
A UTF-8 box that is not valid JSON passes 663, then 666 `if let Err(e) = serde_json::from_slice::<serde_json::Value>`
logs `ASSERTION_JSON_INVALID` (672) with `.failure(...)?` (678): recorded, loading continues, under the default log.

**4. The CBOR box.** 715 `Assertion::from_data_cbor(&raw_label, cbor_box.cbor())` has no `?`; `assertion.rs` 425-431
returns an `Assertion`, not a `Result`. The only check is 718 (`c2pa_cbor::from_slice::<c2pa_cbor::Value>`), logged as
`ASSERTION_CBOR_INVALID` (724), `.failure(...)?` (730): recorded, loading continues. A missing data box aborts in both
arms: `.ok_or(Error::JumbfBoxNotFound)?` (661, 714).

**5. The stop-on-first-error log (1924).** `store_core.rs` 1924: `let mut report =
StatusTracker::with_error_behavior(ErrorBehavior::StopOnFirstError);` inside `load_ingredient_to_claim` (1912), used at
1925 and 2064 for `from_jumbf_with_context`. With it, 678 and 730 return `Err` and the ingredient fails to load. The
name occurs once across the files read (text search over all eleven downloaded source files): its
definition. No file read calls it, so the reader does not reach it. Its callers: **not determined**; a text search of a
checkout of the tag for `load_ingredient_to_claim` would settle it.

**6. The other JSON route (`manifest.rs`).** `Reader::with_store` is run after every load (`reader.rs` 242, 317, 328,
...) and calls `Manifest::from_store` per claim (899). `manifest.rs` 669-688: the catch-all arm does `AssertionData::Cbor(_)
=> { let value = assertion.as_json_object()?;` (673) and the same for `Json(_)` (681). `assertion.rs` 338-340: CBOR is
decoded again with `c2pa_cbor::from_slice(x)` `.map_err(...)?`; 335-336 for JSON `serde_json::from_str(x)`. So a box the
store only recorded now returns `Err` from `from_store`. `reader.rs` 917-936: `Err(e) => {` ... `.failure(validation_log,
Error::C2PAValidation(e.to_string()))?;` logs "Failed to load manifest" and, with the default log, goes on to the next
claim; the manifest is never inserted (928 is in the `Ok` arm). Consequence: that whole manifest, not just the
assertion, is absent from `Reader::manifests()` (744). `active_manifest()` (725-731) is `self.manifests.get(label)`, so
if the bad box is in the active manifest it returns `None`, although `active_label()` (734) still names it
(set at 958). Binary and UUID boxes are skipped without error (691-692).

**7. The crJSON route does not use that map.** `crjson.rs` 236 `let claims = self.reader.store.claims();` and 462
`_ => Ok(assertion.as_json_object().ok().map(fix_hash_encoding))`: the assertion is left out, the manifest stays
(`from_reader` 213, called from `reader.rs` 595-596; `crjson()` 603-605 returns `"{}"` only if `crjson_checked` errs).

## Summary table (default log, the only one the reader builds)

| Malformed box | Read as a whole | `crjson()` | `manifests()` / `active_manifest()` |
|---|---|---|---|
| CBOR, invalid | loads, status recorded | assertion omitted | manifest absent; active is `None` |
| JSON, UTF-8, invalid | loads, status recorded | assertion omitted | manifest absent; active is `None` |
| JSON, not UTF-8 | read fails, no Reader | none | none |

## What a product would have to build

A verifier that shows a custom assertion must not read `manifests()` alone: one bad box hides the whole manifest and
its signer there. Read the crJSON output and the validation status together, and show "assertion present but
unreadable" from the status code. A producer should write valid UTF-8 JSON or well-formed CBOR and test its own
output with the pinned reader.

## A test that would confirm or kill this

Three tiny signed files differing only in one custom box (invalid CBOR; UTF-8 text that is not JSON; bytes not UTF-8),
each read once with the pinned reader's file route. Prediction: the first two give a Reader whose crJSON lacks the
assertion and whose validation status lists the invalid-box code, with `manifests()` lacking the manifest; the third
gives an error. Any Reader returned for the third, or a manifest present for the first two, kills finding 6 or 3.

## Not verified

Nothing was run, so every statement is from source text. Not read: `validation_status.rs` (the string values of the two
status codes and `code_from_error` used at `reader.rs` 932), `store_verify.rs` (whether a validly signed claim whose
box is malformed passes the hash check: the hash at `store_core.rs` 733 is taken over the stored bytes, so likely yes;
**not determined**), `error.rs` (the `From` conversion behind `?` at 663), the callers in finding 5, any public
`Reader` entry other than those that call the six `with_*` functions above, and the test files. The `async` variants
were taken to match the sync ones where the generated names show it; not read separately.
