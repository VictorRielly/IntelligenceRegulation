"""Coordinator's recheck of applications item A36 (how the standard's open Rust library writes a custom assertion in
its crJSON output), plus two files the handoff did not read (the validation log).

Usage: python3 -I <this file> DIR
DIR holds the coordinator's own downloads, made on 2026-11-27 with a generic User-Agent, each in a directory of its
own: DIR/tree/tree.json (the recursive tree listing of the pinned commit) and DIR/<key>/file.rs.txt for the keys
crjson, reader, assertion, jsonb64, storecore, test, logitem, tracker (fetched from the raw address of the pinned
commit plus the path the tree lists). The files are read as data; nothing in them is executed. Every check prints one
line; the exit code is 0 only if all pass."""
import json
import sys

D = sys.argv[1].rstrip('/') + '/'
C = 'd8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b'
PATHS = {'crjson': 'sdk/src/crjson.rs', 'reader': 'sdk/src/reader.rs', 'assertion': 'sdk/src/assertion.rs',
         'jsonb64': 'sdk/src/utils/json_b64.rs', 'storecore': 'sdk/src/store/store_core.rs',
         'test': 'sdk/tests/crjson/created_gathered.rs', 'logitem': 'sdk/src/status_tracker/log_item.rs',
         'tracker': 'sdk/src/status_tracker/mod.rs'}
n = bad = 0


def ok(cond, what):
    global n, bad
    n += 1
    if not cond:
        bad += 1
    print(('ok   ' if cond else 'FAIL ') + what)


tree = json.load(open(D + 'tree/tree.json', encoding='utf-8'))
blobs = {e['path']: e['size'] for e in tree['tree'] if e['type'] == 'blob'}
F = {}
sizes = True
for k, p in PATHS.items():
    raw = open(D + k + '/file.rs.txt', 'rb').read()
    sizes = sizes and len(raw) == blobs[p]
    F[k] = raw.decode('utf-8').split('\n')


def at(k, i, sub):
    line = F[k][i - 1] if 0 < i <= len(F[k]) else ''
    ok(sub in line, '%s:%d contains %r' % (PATHS[k][4:], i, sub) + ('' if sub in line else ' | found %r' % line[:120]))


def rng(k, a, b):
    return '\n'.join(F[k][a - 1:b])


# --- the pinned source
ok(tree['sha'] == C and tree['truncated'] is False and len(tree['tree']) == 778, 'tree listing: the pinned commit, not truncated, 778 entries')
ok(sizes, 'each of the eight files has the size the tree listing gives')
ok([blobs[PATHS[k]] for k in ('crjson', 'reader', 'assertion', 'jsonb64', 'storecore', 'test')] == [54327, 74723, 25265, 8805, 86385, 8475],
   'the six files the handoff lists have the sizes it gives')
tests = sorted(p for p in blobs if p.startswith('sdk/tests/crjson/'))
ok(len(tests) == 6 and 'sdk/tests/crjson/mod.rs' in tests and 'sdk/tests/crjson_tests.rs' in blobs
   and 'sdk/tests/fixtures/schemas/crJSON-schema.json' in blobs,
   'the tree lists six files under sdk/tests/crjson/ (five test files, as the handoff says, and mod.rs), crjson_tests.rs and the schema')
ok(sum(1 for p in blobs if p.endswith('crjson.rs') and p.startswith('sdk/src/')) == 1, 'one crjson.rs under sdk/src')

# --- the call chain
at('reader', 595, 'pub fn to_crjson_value(&self) -> Result<Value> {')
at('reader', 596, 'crate::crjson::from_reader(self)')
at('reader', 603, 'pub fn crjson(&self) -> String {')
at('reader', 604, 'self.crjson_checked().unwrap_or_else(|_| "{}".to_string())')
at('reader', 610, 'pub fn crjson_checked(&self) -> Result<String> {')
at('crjson', 213, 'pub fn from_reader')

# --- finding 1: CBOR and JSON data come out under the label
at('crjson', 357, 'ClaimAssertion::label() already encodes the instance suffix as `base__N`')
at('crjson', 358, 'for ca in claim.claim_assertion_store() {')
at('crjson', 359, 'let key = ca.label();')
at('crjson', 363, 'if let Some(value) = self.claim_assertion_to_value(manifest_label, ca)? {')
at('crjson', 364, 'assertions_obj.insert(key, value);')
at('crjson', 413, 'Everything else is decoded via [`Assertion::as_json_object`] and passed through')
at('crjson', 424, 'if ca.label_raw().starts_with(assertion_labels::INGREDIENT) {')
at('crjson', 462, '_ => Ok(assertion.as_json_object().ok().map(fix_hash_encoding)),')
body = rng('crjson', 415, 464)
ok(body.count('label') > 0 and all(s not in body for s in ('"c2pa.', 'starts_with("', '== "')),
   'claim_assertion_to_value (crjson.rs:415-464) tests no literal label: only the ingredient prefix and the two thumbnail prefixes, by constant')
at('assertion', 335, 'AssertionData::Json(x) => serde_json::from_str(x)')
at('assertion', 338, 'AssertionData::Cbor(x) => {')
at('assertion', 341, 'Ok(cbor_to_json_b64(value))')
at('jsonb64', 66, 'Cbor::Integer(i) => Value::Number(i.into()),')
at('jsonb64', 70, 'Cbor::Bytes(b) => Value::String(encode_b64_wrapped(&b)),')
at('jsonb64', 71, 'Cbor::Text(s) => Value::String(s),')
at('jsonb64', 73, 'Cbor::Map(m) => {')
at('jsonb64', 76, 'obj.insert(cbor_key_to_string(k), cbor_to_json_b64(v));')
at('jsonb64', 15, 'Conversion uses `c2pa_cbor` and inherits its supported integer range.')
ok('This is not a lossless mapping of arbitrary CBOR maps.' in ' '.join(x.strip().lstrip('/').strip() for x in F['jsonb64'][54:59]),
   'json_b64.rs:55-59 says the mapping is not lossless')

# --- finding 2: binary and UUID boxes become a reference object
at('crjson', 435, 'AssertionData::Binary(_) | AssertionData::Uuid(_, _) => {')
at('crjson', 457, '"format": assertion.content_type(),')
at('crjson', 458, '"identifier": absolute_uri,')
at('crjson', 459, '"hash": base64::encode_b64_wrapped(ca.hash())')
at('storecore', 711, 'CAI_CBOR_ASSERTION_UUID => {')
ok('CAI_JSON_ASSERTION_UUID' in rng('storecore', 655, 665) and 'CAI_UUID_ASSERTION_UUID' in rng('storecore', 741, 750),
   'store_core.rs: the JSON box arm near 657-663 and the UUID box arm near 743-748')

# --- finding 3: an undecodable value is omitted; the invalid-CBOR log line
at('storecore', 718, 'if let Err(e) = c2pa_cbor::from_slice::<c2pa_cbor::Value>(cbor_box.cbor()) {')
at('storecore', 724, '.validation_status(ASSERTION_CBOR_INVALID)')
at('storecore', 725, '.failure(')
at('storecore', 730, ')?;')

# --- finding 4: fields rewritten in any assertion
at('crjson', 690, 'fn fix_hash_encoding(value: Value) -> Value {')
at('crjson', 694, 'const SCHEMA_ORG_OS_KEY: &str = "schema.org.SoftwareApplication.operatingSystem";')
at('crjson', 701, 'for field in &["hash", "pad", "pad2"] {')
at('crjson', 718, '// Ensure hash-bearing objects also carry a (possibly empty) pad field.')
at('crjson', 719, 'if map.contains_key("hash") && !map.contains_key("pad") {')
ok('"signature"' in rng('crjson', 723, 740) and 'decode_cawg_signature' in rng('crjson', 723, 740), 'crjson.rs:723-740 rewrites a signature value')
ok('"icon"' in rng('crjson', 746, 762) and all(s in rng('crjson', 746, 762) for s in ('"url"', '"hash"', '"alg"')),
   'crjson.rs:748-760 cuts an icon object down to url, hash, alg')
ok('fix_hash_encoding' in rng('crjson', 741, 768), 'the function recurses into nested values')

# --- finding 6: gathered assertions of another claim
ok('"identifier"' in rng('crjson', 390, 400) and '"hash"' in rng('crjson', 390, 400), 'crjson.rs:393-398 an unresolved gathered assertion is {identifier, hash}')

# --- finding 7: the library's test checks presence
t = rng('test', 34, 58)
ok(all(s in t for s in ('org.test.gathered', 'org.test.created', 'org.test.regular')), 'test file lines 34-58 name the three labels')
ok(rng('test', 78, 84).count('contains_key') >= 3, 'test file lines 80-82 check contains_key for them')

# --- the coordinator's additions: does an invalid CBOR box abort the read? (the handoff queued this as A38)
at('logitem', 256, 'pub fn failure<E: Debug>(mut self, tracker: &mut StatusTracker, err: E) -> Result<E, E> {')
at('logitem', 259, 'tracker.add_error(self, err)')
at('tracker', 93, 'pub fn add_error<E>(&mut self, mut log_item: LogItem, err: E) -> Result<E, E> {')
at('tracker', 106, 'ErrorBehavior::StopOnFirstError => Err(err),')
at('tracker', 107, 'ErrorBehavior::ContinueWhenPossible => Ok(err),')
at('tracker', 21, '#[derive(Debug, Default)]')
at('tracker', 22, 'pub struct StatusTracker {')
at('tracker', 189, '#[derive(Debug, Default, Eq, PartialEq)]')
at('tracker', 196, '#[default]')
at('tracker', 197, 'ContinueWhenPossible,')
made = [i + 1 for i, l in enumerate(F['reader']) if 'StatusTracker::' in l]
ok(len(made) == 9 and all('StatusTracker::default()' in F['reader'][i - 1] for i in made),
   'reader.rs builds its validation log in 9 places, each with StatusTracker::default()')
ok(not any('ErrorBehavior' in l for l in F['reader']), 'reader.rs never names ErrorBehavior')
at('storecore', 663, 'let assertion = Assertion::from_data_json(&raw_label, json_box.json())?;')
at('storecore', 666, 'if let Err(e) = serde_json::from_slice::<serde_json::Value>(json_box.json()) {')
at('storecore', 672, '.validation_status(ASSERTION_JSON_INVALID)')
at('storecore', 678, ')?;')
stops = [i + 1 for i, l in enumerate(F['storecore']) if 'StopOnFirstError' in l]
ok(stops == [1924], 'store_core.rs builds a stop-on-first-error log in one place, line 1924 (which call uses it was not read)')

print('%d checks, %d failed' % (n, bad))
sys.exit(1 if bad else 0)
