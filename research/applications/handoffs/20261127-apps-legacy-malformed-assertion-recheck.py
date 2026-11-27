"""Coordinator's recheck of applications item A39 (what the older reader library, at the revision the legacy toolkit
pins, and the legacy JavaScript library do with a custom assertion whose CBOR or JSON box does not parse).

Usage: python3 -I <this file> DIR
DIR holds the coordinator's own downloads, made on 2026-11-27 with a generic User-Agent, each in a directory of its
own: DIR/<key>/file.txt for the keys below (fetched from the raw address of the pinned commit plus the path). The
files are read as data; nothing in them is executed. The handoff beside this script is read for its table of sizes and
hashes. Every check prints one line; the exit code is 0 only if all pass."""
import hashlib
import os
import re
import sys

D = sys.argv[1].rstrip('/') + '/'
CR = '0a29852b0546596972c7105a7a510b12e050dc67'
CJ = 'c8c2912e2855c857277c0e1a6535a6db18e13c8e'
PATHS = {'tracker': 'sdk/src/status_tracker/mod.rs', 'log_item': 'sdk/src/status_tracker/log_item.rs',
         'rsstore': 'sdk/src/manifest_store.rs', 'store': 'sdk/src/store.rs', 'assertion': 'sdk/src/assertion.rs',
         'manifest': 'sdk/src/manifest.rs', 'types': 'packages/toolkit/types/index.ts', 'c2pa': 'packages/c2pa/src/c2pa.ts',
         'lib': 'packages/toolkit/src/lib.rs', 'tkstore': 'packages/toolkit/src/manifest_store.rs'}
# three files of the legacy JavaScript library the handoff did not read (same commit); hashes of the coordinator's copies
EXTRA = {'jsstore': ('packages/c2pa/src/manifestStore.ts', 5207, 'd3d57c2d3f79941f07dd874638ed40ea21dfe1e0466760d5544f08a679fe31f9'),
         'jsmanifest': ('packages/c2pa/src/manifest.ts', 4640, '7d5ad035c441cbbcca0e4c197cb49e7699f45a221e85b89d435e08cdd4113675'),
         'jsingredient': ('packages/c2pa/src/ingredient.ts', 3006, '88a9799daed82332eed5a1dd436c5ef6ea43a61aeceac8836c69b71c937b63a0')}
HAND = open(os.path.dirname(os.path.abspath(__file__)) + '/20261127-apps-legacy-malformed-assertion.md', encoding='utf-8').read()
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
    raw = open(D + k + '/file.txt', 'rb').read()
    row = '| `%s` | %d | %s |' % (p, len(raw), hashlib.sha256(raw).hexdigest())
    same = same and row in HAND
    F[k] = raw.decode('utf-8').split('\n')
ok(same and CR in HAND and CJ in HAND, 'each of the ten own copies has the byte length and SHA-256 the handoff lists for it, at the two pinned commits')
same = True
for k, (p, size, h) in EXTRA.items():
    raw = open(D + k + '/file.txt', 'rb').read()
    same = same and len(raw) == size and hashlib.sha256(raw).hexdigest() == h
    PATHS[k] = p
    F[k] = raw.decode('utf-8').split('\n')
ok(same, 'the three further files (manifestStore.ts, manifest.ts, ingredient.ts of the legacy library) have the lengths and hashes written in this script')


def short(k):
    p = PATHS[k]
    return p[8:] if p.startswith('sdk/src/') else p.split('/', 1)[1] if p.startswith('packages/') else p


def at(k, i, sub):
    line = F[k][i - 1] if 0 < i <= len(F[k]) else ''
    ok(sub in line, '%s:%d contains %r' % (short(k), i, sub) + ('' if sub in line else ' | found %r' % line[:120]))


def where(k, sub):
    return [i + 1 for i, l in enumerate(F[k]) if sub in l]


# 1. the log's default: record and go on
at('tracker', 23, '#[derive(Debug, Default)]')
at('tracker', 24, 'pub struct StatusTracker')
at('tracker', 97, 'ErrorBehavior::StopOnFirstError => Err(err),')
at('tracker', 98, 'ErrorBehavior::ContinueWhenPossible => Ok(err),')
at('tracker', 190, 'impl Default for ErrorBehavior {')
at('tracker', 192, 'Self::ContinueWhenPossible')
at('log_item', 235, 'pub fn failure<E: Debug>(mut self, tracker: &mut StatusTracker, err: E) -> Result<E, E>')
at('log_item', 238, 'tracker.add_error(self, err)')

# 2. the toolkit's two routes build that default log
at('tkstore', 18, 'ManifestStore::from_bytes_async(mime_type, data, true)')
at('tkstore', 32, 'ManifestStore::from_manifest_and_asset_bytes_async(manifest_bytes, format, asset_bytes)')
at('rsstore', 257, '#[async_generic]')
at('rsstore', 258, 'pub fn from_bytes(format: &str, image_bytes: &[u8], verify: bool) -> Result<ManifestStore> {')
at('rsstore', 259, 'let mut validation_log = StatusTracker::default();')
at('rsstore', 264, 'Store::load_from_memory_async(format, image_bytes, verify, &mut validation_log).await')
at('rsstore', 272, 'Ok(Self::from_store_async(store, &validation_log).await)')
at('rsstore', 453, 'let mut validation_log = StatusTracker::default();')
at('rsstore', 454, 'let store = Store::from_jumbf(manifest_bytes, &mut validation_log)?;')
rtests = [i + 1 for i, l in enumerate(F['rsstore']) if l.strip() == 'mod tests {']
ok(rtests == [564] and where('rsstore', 'StopOnFirstError') == [246, 591] and 'pub fn from_manifest(manifest: &Manifest) -> Result<Self> {' in F['rsstore'][238],
   'manifest_store.rs builds a stopping log at line 246 (in from_manifest, which starts from a manifest and not from a file) and at 591 in its test module (opens at 564); nowhere else')
at('store', 4355, 'let store = Store::get_store_from_memory(asset_type, data, validation_log)?;')
at('store', 4143, 'Self::load_cai_from_memory(asset_type, data, validation_log)')
at('store', 3968, '.map(|(manifest_bytes, _)| Store::from_jumbf(&manifest_bytes, validation_log))?')
tests = [i + 1 for i, l in enumerate(F['store']) if l.strip().startswith('pub mod tests') or l.strip().startswith('mod tests')]
stops = [i for i in where('store', 'StopOnFirstError') if i < tests[0]]
ok(tests[:1] == [4961] and stops == [514, 580, 2688, 2870, 4674],
   'store.rs builds a stopping log at five lines before its test module (514, 580, 2688, 2870, 4674; the module opens at 4961; the handoff writes 4960, its attribute line)')


def fn_before(k, i):
    for j in range(i - 1, -1, -1):
        m = re.match(r'\s*(pub(\([a-z]+\))? )?(async )?fn ([a-zA-Z0-9_]+)', F[k][j])
        if m:
            return m.group(4)


ok([fn_before('store', i) for i in stops] == ['get_ocsp_status', 'sign_claim', 'save_to_bmff_fragmented', 'save_to_stream', 'load_ingredient_to_claim'],
   'the five are in get_ocsp_status, sign_claim, save_to_bmff_fragmented, save_to_stream and load_ingredient_to_claim, none on the two routes')

# 3. the box tests in the claim loader
at('store', 796, 'let assertion = Assertion::from_data_json(&raw_label, json_box.json())?;')
at('store', 799, 'if let Err(e) = serde_json::from_slice::<serde_json::Value>(json_box.json()) {')
at('store', 805, '.validation_status(ASSERTION_JSON_INVALID)')
at('store', 806, '.failure(')
at('store', 811, ')?;')
at('store', 848, 'let assertion = Assertion::from_data_cbor(&raw_label, cbor_box.cbor());')
at('store', 851, 'if let Err(e) = serde_cbor::from_slice::<serde_cbor::Value>(cbor_box.cbor()) {')
at('store', 857, '.validation_status(ASSERTION_CBOR_INVALID)')
at('store', 863, ')?;')
at('store', 1370, 'match Store::get_assertion_from_jumbf_store(')
at('store', 1375, 'validation_log,')
at('store', 1377, 'Ok(assertion) => {')
at('store', 1378, 'claim.put_assertion_store(assertion);')
at('store', 1381, 'Err(e) => {')
at('store', 1391, 'return Err(e);')
at('assertion', 430, 'pub(crate) fn from_data_cbor(label: &str, binary_data: &[u8]) -> Assertion {')
at('assertion', 441, ') -> AssertionDecodeResult<Assertion> {')
at('assertion', 442, 'let json = String::from_utf8(binary_data.to_vec()).map_err(|_| AssertionDecodeError {')
at('assertion', 446, 'source: AssertionDecodeErrorCause::BinaryDataNotUtf8,')
at('assertion', 447, '})?;')

# 4. the conversion of a claim into a manifest, and the list it is put in
at('assertion', 331, 'pub(crate) fn as_json_object(&self) -> AssertionDecodeResult<Value> {')
at('assertion', 333, 'AssertionData::Json(x) => serde_json::from_str(x)')
at('assertion', 341, 'serde_transcode::transcode(&mut from, &mut to)')
at('assertion', 342, '.map_err(|e| AssertionDecodeError::from_assertion_and_json_err(self, e))?;')
at('manifest', 570, 'pub(crate) fn from_store(')
at('manifest', 574, ') -> Result<Self> {')
at('manifest', 762, 'AssertionData::Cbor(_) => {')
at('manifest', 763, 'let value = assertion.as_json_object()?;')
at('manifest', 769, 'AssertionData::Json(_) => {')
at('manifest', 770, 'let value = assertion.as_json_object()?;')
at('manifest', 779, 'AssertionData::Binary(_x) => {}')
at('rsstore', 206, 'manifest_store.active_manifest = store.provenance_label();')
at('rsstore', 213, 'let result = Manifest::from_store_async(store, manifest_label, options).await;')
at('rsstore', 218, 'Ok(manifest) => {')
at('rsstore', 221, '.insert(manifest_label.to_owned(), manifest);')
at('rsstore', 223, 'Err(e) => {')
at('rsstore', 224, 'validation_results.add_status(ValidationStatus::from_error(&e));')
at('rsstore', 169, 'manifest_store.active_manifest = store.provenance_label();')
at('rsstore', 187, 'validation_results.add_status(ValidationStatus::from_error(&e));')
ok(where('rsstore', '.insert(manifest_label.to_owned(), manifest);') == [184, 221],
   'manifest_store.rs puts a manifest in the list at two lines only (184 and 221), each inside the Ok arm of its builder')

# 5. the legacy library's outer read call
at('c2pa', 236, 'try {')
at('c2pa', 237, 'const result = await pool.getReport(wasm, buffer, source.type, settings);')
at('c2pa', 243, 'manifestStore: createManifestStore(result.manifest_store, cawg),')
at('c2pa', 246, '} catch (err: any) {')
at('c2pa', 247, 'const manifestStore = await handleErrors(')
at('c2pa', 291, '/^C2pa\\(ProvenanceMissing\\)$/,')
at('c2pa', 293, '/^C2pa\\(JumbfParseError\\([^\\)]+\\)\\)$/,')
at('c2pa', 295, '/^C2pa\\(Jumbf(?:Box)?NotFound\\)$/,')
at('c2pa', 318, "if (error.name === 'Toolkit(RemoteManifestUrl)') {")
at('c2pa', 325, 'if (ignoreErrors.some((re) => re.test(error.name))) {')
at('c2pa', 327, 'return null;')
at('c2pa', 330, 'throw error;')

# 6. the toolkit's types
at('types', 27, 'active_manifest: string;')
at('types', 28, 'manifests: Record<string, Manifest>;')
at('types', 29, 'validation_status: ValidationStatus[];')
at('types', 50, 'code: string;')
at('types', 107, 'assertions: Assertion[];')
at('types', 113, "type ManifestAssertionKind = 'Cbor' | 'Json' | 'Binary' | 'Uri';")
at('types', 115, 'export type AssertionData<U = unknown> = {')
at('types', 119, 'export interface Assertion<T = string, U = unknown> {')
at('types', 121, 'data: AssertionData<U>;')
at('types', 171, 'export type ManifestAssertion =')
at('types', 312, 'export interface ToolkitError extends Error {')

# 7. added by this check: what the legacy library does with a store whose list lacks a manifest
at('jsstore', 89, 'export function createManifestStore(')
at('jsstore', 93, 'const manifests = createManifests(')
at('jsstore', 100, 'activeManifest: manifests[manifestStoreData.active_manifest],')
at('jsstore', 127, 'data: toolkitManifests[toolkitActiveManifestId],')
at('jsstore', 137, 'const { data: currentManifest } = current;')
at('jsstore', 139, 'currentManifest?.ingredients?.forEach(({ active_manifest: manifestId }) => {')
at('jsstore', 141, 'if (manifestStoreData.manifests[manifestId]) {')
at('jsstore', 147, "dbg('No manifest found for id', manifestId);")
at('jsstore', 155, 'const { data: manifestData, label } = stackManifestData;')
at('jsstore', 158, 'const manifest = createManifest(manifestData, manifests, cawgData);')
at('jsmanifest', 128, 'export function createManifest(')
at('jsmanifest', 129, 'manifestData: ToolkitManifest,')
at('jsmanifest', 133, 'const ingredients = manifestData.ingredients.map((ingredientData) =>')
at('jsmanifest', 137, '? manifests[ingredientData.active_manifest]')
ok(not any('manifestData?' in l or 'if (!manifestData' in l for l in F['jsmanifest'][127:134]),
   'manifest.ts:128-134: no test of manifestData before its ingredients are read, so an undefined one throws a TypeError there (the language\x27s rule; not run)')
at('jsingredient', 91, 'manifest?: Manifest,')
at('jsingredient', 103, 'manifest: manifest ?? null,')
pats = [re.compile(r'^C2pa\(ProvenanceMissing\)$'), re.compile(r'^C2pa\(JumbfParseError\([^\)]+\)\)$'), re.compile(r'^C2pa\(Jumbf(?:Box)?NotFound\)$')]
ok(not any(p.match('TypeError') for p in pats) and 'TypeError' != 'Toolkit(RemoteManifestUrl)',
   'the name TypeError is none of the three ignored patterns and not the remote-manifest name, so handleErrors reaches line 330 and read rejects')

print('%d checks, %d failed' % (n, bad))
sys.exit(1 if bad else 0)
