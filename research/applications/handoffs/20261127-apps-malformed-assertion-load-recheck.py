"""Coordinator's recheck of applications item A38 (what the standard's open Rust library does with a custom assertion
whose CBOR or JSON box does not parse).

Usage: python3 -I <this file> DIR
DIR holds the coordinator's own downloads, made on 2026-11-27 with a generic User-Agent, each in a directory of its
own: DIR/<key>/file.rs.txt for the keys store_core, store_io, tracker, log_item, reader, manifest, assertion, crjson
(fetched from the raw address of the pinned commit plus the path below). The files are read as data; nothing in them
is executed. The handoff beside this script is read for its table of sizes and hashes. Every check prints one line; the
exit code is 0 only if all pass."""
import hashlib
import os
import sys

D = sys.argv[1].rstrip('/') + '/'
C = 'd8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b'
PATHS = {'store_core': 'sdk/src/store/store_core.rs', 'store_io': 'sdk/src/store/store_io.rs',
         'tracker': 'sdk/src/status_tracker/mod.rs', 'log_item': 'sdk/src/status_tracker/log_item.rs',
         'reader': 'sdk/src/reader.rs', 'manifest': 'sdk/src/manifest.rs', 'assertion': 'sdk/src/assertion.rs',
         'crjson': 'sdk/src/crjson.rs'}
HAND = open(os.path.dirname(os.path.abspath(__file__)) + '/20261127-apps-malformed-assertion-load.md', encoding='utf-8').read()
n = bad = 0


def ok(cond, what):
    global n, bad
    n += 1
    if not cond:
        bad += 1
    print(('ok   ' if cond else 'FAIL ') + what)


F = {}
same = True
for k, p in PATHS.items():
    raw = open(D + k + '/file.rs.txt', 'rb').read()
    row = '| `%s` | %d | %s |' % (p, len(raw), hashlib.sha256(raw).hexdigest())
    same = same and row in HAND
    F[k] = raw.decode('utf-8').split('\n')
ok(same and C in HAND, 'each of the eight own copies has the byte length and SHA-256 the handoff lists for it, at the pinned commit')


def at(k, i, sub):
    line = F[k][i - 1] if 0 < i <= len(F[k]) else ''
    ok(sub in line, '%s:%d contains %r' % (PATHS[k][8:], i, sub) + ('' if sub in line else ' | found %r' % line[:120]))


def where(k, sub):
    return [i + 1 for i, l in enumerate(F[k]) if sub in l]


# 1. the log: a failure is recorded and returned as Ok unless the log was built to stop
at('tracker', 21, '#[derive(Debug, Default)]')
at('tracker', 22, 'pub struct StatusTracker')
at('tracker', 106, 'ErrorBehavior::StopOnFirstError => Err(err),')
at('tracker', 107, 'ErrorBehavior::ContinueWhenPossible => Ok(err),')
at('tracker', 196, '#[default]')
at('tracker', 197, 'ContinueWhenPossible,')
at('log_item', 256, 'pub fn failure<E: Debug>(mut self, tracker: &mut StatusTracker, err: E) -> Result<E, E>')
at('log_item', 259, 'tracker.add_error(self, err)')

# 2. the reader builds only default logs; six of the nine are handed to a loading call
ok(where('reader', 'StatusTracker::default()') == [225, 284, 297, 367, 413, 484, 973, 1051, 1301] and not where('reader', 'ErrorBehavior'),
   'reader.rs builds a default log at nine lines (225, 284, 297, 367, 413, 484, 973, 1051, 1301) and never names the stopping behaviour')
at('reader', 236, 'Store::from_stream(format, stream, &mut validation_log, &self.context)')
at('reader', 286, 'Store::from_stream(&format, &mut file, &mut validation_log, &self.context)')
at('reader', 299, 'Store::from_manifest_data_and_stream(')
at('reader', 370, 'Store::from_manifest_data_and_stream(')
at('reader', 416, 'Store::load_fragment_from_stream(')
at('reader', 494, 'Store::load_from_file_and_fragments(')
at('reader', 972, 'pub fn post_validate(')
at('reader', 1003, 'fn walk_manifest(')
at('reader', 1223, '#[cfg(test)]')
ok(972 < 973 < 1003 < 1051 < 1223 < 1301, 'the other three default logs are in post_validate, in walk_manifest and in the test module')
at('store_io', 1315, 'Store::from_jumbf_with_context(c2pa_data, validation_log, context)')
at('store_io', 1351, 'Store::from_jumbf_with_context(&manifest_bytes, validation_log, context)?;')
at('store_io', 1400, 'Store::from_jumbf_with_context(&manifest_bytes, validation_log, context)?;')
at('store_core', 988, 'Self::from_jumbf_impl(')
at('store_core', 1295, 'match Store::get_assertion_from_jumbf_store(')
at('store_core', 1299, 'validation_log,')

# 3. the JSON box: only text that is not UTF-8 returns an error before the log is asked
at('store_core', 661, '.ok_or(Error::JumbfBoxNotFound)?;')
at('store_core', 663, 'let assertion = Assertion::from_data_json(&raw_label, json_box.json())?;')
at('store_core', 666, 'if let Err(e) = serde_json::from_slice::<serde_json::Value>(json_box.json()) {')
at('store_core', 672, '.validation_status(ASSERTION_JSON_INVALID)')
at('store_core', 673, '.failure(')
at('store_core', 678, ')?;')
at('assertion', 437, 'let json = String::from_utf8(binary_data.to_vec()).map_err(|_| AssertionDecodeError {')
at('assertion', 441, 'source: AssertionDecodeErrorCause::BinaryDataNotUtf8,')
at('assertion', 442, '})?;')
at('assertion', 444, 'Ok(Self::from_assertion_data(')
at('store_core', 1305, 'Err(e) => {')
at('store_core', 1315, 'return Err(e);')
at('reader', 239, '}?;')

# 4. the CBOR box: built without a check, then tested, the failure handed to the log
at('store_core', 714, '.ok_or(Error::JumbfBoxNotFound)?;')
at('store_core', 715, 'let assertion = Assertion::from_data_cbor(&raw_label, cbor_box.cbor());')
at('assertion', 425, 'pub(crate) fn from_data_cbor(label: &str, binary_data: &[u8]) -> Assertion {')
at('store_core', 718, 'if let Err(e) = c2pa_cbor::from_slice::<c2pa_cbor::Value>(cbor_box.cbor()) {')
at('store_core', 724, '.validation_status(ASSERTION_CBOR_INVALID)')
at('store_core', 730, ')?;')
at('store_core', 733, 'let hash = Claim::calc_assertion_box_hash(&label, &assertion, salt.clone(), &alg)?;')
at('store_core', 734, 'Ok(ClaimAssertion::new(')
at('store_core', 1302, 'claim.put_assertion_store(assertion);')

# 5. the one log built to stop is in ingredient loading, a function none of these eight files calls
at('store_core', 1912, 'pub fn load_ingredient_to_claim(')
at('store_core', 1924, 'let mut report = StatusTracker::with_error_behavior(ErrorBehavior::StopOnFirstError);')
at('store_core', 1925, 'let i_store = Store::from_jumbf_with_context(data, &mut report, context)?;')
at('store_core', 2064, 'Store::from_jumbf_with_context(data, &mut report, context)?;')
ok(sum(len(where(k, 'load_ingredient_to_claim')) for k in F) == 1, 'the name load_ingredient_to_claim occurs once in the eight files: its definition')

# 6. the manifest map: the same box makes the manifest's own conversion fail, and the manifest is left out
at('reader', 242, 'self.with_store(store, &mut validation_log)')
at('reader', 886, 'pub(crate) fn with_store(')
at('reader', 896, 'for claim in arc_store.claims() {')
at('reader', 899, 'Manifest::from_store(')
at('manifest', 549, 'let assertion = claim_assertion.assertion();')
at('manifest', 554, 'match base_label.as_ref() {')
at('manifest', 669, '_ => {')
at('manifest', 671, 'match assertion.decode_data() {')
at('manifest', 672, 'AssertionData::Cbor(_) => {')
at('manifest', 673, 'let value = assertion.as_json_object()?;')
at('manifest', 680, 'AssertionData::Json(_) => {')
at('manifest', 681, 'let value = assertion.as_json_object()?;')
at('manifest', 691, 'AssertionData::Binary(_x) => {}')
at('manifest', 692, 'AssertionData::Uuid(_, _) => {}')
at('assertion', 333, 'pub(crate) fn as_json_object(&self) -> AssertionDecodeResult<Value> {')
at('assertion', 335, 'AssertionData::Json(x) => serde_json::from_str(x)')
at('assertion', 339, 'let value: c2pa_cbor::Value = c2pa_cbor::from_slice(x)')
at('assertion', 340, '.map_err(|e| AssertionDecodeError::from_assertion_and_cbor_err(self, e))?;')
at('reader', 918, 'Ok(mut manifest) => {')
at('reader', 928, 'manifests.insert(manifest_label.to_owned(), manifest);')
at('reader', 930, 'Err(e) => {')
at('reader', 933, 'log_item!(uri.clone(), "Failed to load manifest", "Reader::from_store")')
at('reader', 935, '.failure(validation_log, Error::C2PAValidation(e.to_string()))?;')
ok(where('reader', 'manifests.insert(') == [928], 'reader.rs inserts into the manifest map at one line only, inside the Ok arm')
at('reader', 891, 'let active_manifest = store.provenance_label();')
at('reader', 958, 'self.active_manifest = active_manifest;')
at('reader', 959, 'self.manifests = manifests;')
at('reader', 727, 'self.manifests.get(label)')
at('reader', 735, 'self.active_manifest.as_deref()')
at('reader', 744, 'pub fn manifests(&self) -> &HashMap<String, Manifest> {')

# 7. the crJSON output reads the store's claims and leaves out only the assertion
at('crjson', 213, 'pub fn from_reader(reader: &Reader) -> Result<Value> {')
at('crjson', 236, 'let claims = self.reader.store.claims();')
at('crjson', 462, '_ => Ok(assertion.as_json_object().ok().map(fix_hash_encoding)),')
at('reader', 596, 'crate::crjson::from_reader(self)')
at('reader', 604, 'self.crjson_checked().unwrap_or_else(|_| "{}".to_string())')

print('%d checks, %d failed' % (n, bad))
sys.exit(1 if bad else 0)
