"""Coordinator's recheck of applications item A37 (what the deprecated web toolkit passes to the deprecated
components), plus two files the handoff did not read (the Rust reader's assertion source and its store loader at the
toolkit's pin).

Usage: python3 -I <this file> DIR
DIR holds the coordinator's own downloads, made on 2026-11-27 with a generic User-Agent, each in a directory of its
own: DIR/rev/commit.json (the public commits address for the short revision the toolkit pins) and
DIR/<key>/file.rs.txt for the keys below (fetched from the raw address of the pinned commit of each repository). The
files are read as data; nothing in them is executed. Every check prints one line; the exit code is 0 only if all
pass."""
import json
import sys

D = sys.argv[1].rstrip('/') + '/'
CJ = 'c8c2912e2855c857277c0e1a6535a6db18e13c8e'
PATHS = {  # deprecated web repository at CJ
    'lib': 'packages/toolkit/src/lib.rs', 'tkstore': 'packages/toolkit/src/manifest_store.rs',
    'cargo': 'packages/toolkit/Cargo.toml', 'l2': 'packages/c2pa/src/createL2ManifestStore.ts',
    'popover': 'packages/c2pa-wc/src/components/Popover/Popover.ts', 'manifestts': 'packages/c2pa/src/manifest.ts',
    'assertionsts': 'packages/c2pa/src/assertions.ts', 'manifeststorets': 'packages/c2pa/src/manifestStore.ts',
    # the Rust reader at the revision the toolkit pins
    'rsmanifest': 'sdk/src/manifest.rs', 'rsstore': 'sdk/src/manifest_store.rs', 'rsassertion': 'sdk/src/assertion.rs',
    'rsstorecore': 'sdk/src/store.rs'}
SHOW = {k: ('rs:' if k.startswith('rs') else '') + p.split('/', 2)[2] if k.startswith('rs') is False else 'rs:' + p[4:]
        for k, p in PATHS.items()}
n = bad = 0


def ok(cond, what):
    global n, bad
    n += 1
    if not cond:
        bad += 1
    print(('ok   ' if cond else 'FAIL ') + what)


RAW = {k: open(D + k + '/file.rs.txt', 'rb').read() for k in PATHS}
F = {k: v.decode('utf-8').split('\n') for k, v in RAW.items()}


def at(k, i, sub):
    line = F[k][i - 1] if 0 < i <= len(F[k]) else ''
    ok(sub in line, '%s:%d contains %r' % (SHOW[k], i, sub) + ('' if sub in line else ' | found %r' % line[:120]))


def hits(k, *words):
    return [i + 1 for i, l in enumerate(F[k]) if any(w in l.lower() for w in words)]


# --- the sources
ok([len(RAW[k]) for k in ('lib', 'tkstore', 'l2', 'popover', 'cargo', 'manifestts', 'assertionsts', 'manifeststorets',
                          'rsmanifest', 'rsstore')] == [4986, 1544, 4052, 9577, 999, 4640, 1631, 5207, 114787, 26007],
   'the ten files the handoff read have, in my downloads, the byte counts it gives')
full = json.load(open(D + 'rev/commit.json', encoding='utf-8'))['sha']
ok(full == '0a29852b0546596972c7105a7a510b12e050dc67', 'the short revision 0a29852 resolves to one full commit hash, ' + full)

# --- finding 1: the toolkit serialises the whole store
at('lib', 82, '#[derive(Serialize)]')
at('lib', 83, 'struct AssetReport {')
at('lib', 84, 'manifest_store: c2pa::ManifestStore,')
at('lib', 85, 'cawg_json: String,')
at('lib', 156, 'let report = AssetReport {')
at('lib', 161, 'Serializer::new().serialize_maps_as_objects(true)')
at('lib', 163, '.serialize(&serializer)')
ok(hits('lib', 'assertion', 'label') == [30, 148] and all('IdentityAssertion' in F['lib'][i - 1] for i in (30, 148)),
   'toolkit lib.rs: the words assertion and label occur on lines 30 and 148 only, both IdentityAssertion')
ok(hits('tkstore', 'assertion', 'label') == [], 'toolkit manifest_store.rs: neither word occurs')
at('tkstore', 18, 'ManifestStore::from_bytes_async(mime_type, data, true)')
at('tkstore', 32, 'ManifestStore::from_manifest_and_asset_bytes_async(manifest_bytes, format, asset_bytes)')
at('cargo', 5, 'version = "0.33.3-1"')
at('cargo', 11, 'c2pa = { git = "https://github.com/contentauth/c2pa-rs.git", rev = "0a29852"')
at('cargo', 11, '"v1_api", "file_io", "rust_native_crypto"], default-features = false')

# --- finding 2: the pinned Rust reader copies a CBOR or JSON assertion with any other label into the list
at('rsmanifest', 67, '#[derive(Debug, Default, Deserialize, Serialize)]')
at('rsmanifest', 112, '#[serde(default = "default_vec::<ManifestAssertion>")]')
at('rsmanifest', 113, 'assertions: Vec<ManifestAssertion>,')
ok(not any('skip' in l for l in F['rsmanifest'][110:113]), 'rs:manifest.rs:111-113 carry no skip attribute')
at('rsmanifest', 569, '#[async_generic]')
at('rsmanifest', 570, 'pub(crate) fn from_store(')
at('rsmanifest', 658, 'for assertion in claim.assertions() {')
at('rsmanifest', 670, 'Err(e) => return Err(e),')
at('rsmanifest', 673, 'let label = claim_assertion.label();')
at('rsmanifest', 674, 'let base_label = assertion.label();')
at('rsmanifest', 676, 'match base_label.as_ref() {')
arms = [i for i in range(677, 783) if F['rsmanifest'][i - 1].startswith(' ' * 16) and F['rsmanifest'][i - 1][16] != ' '
        and '=> {' in F['rsmanifest'][i - 1]]
ok(arms == [677, 720, 732, 735, 745, 752, 759], 'the match of line 676 has seven arms, opening at lines %s' % arms)
at('rsmanifest', 677, 'base if base.starts_with(labels::ACTIONS) => {')
at('rsmanifest', 720, 'base if base.starts_with(labels::INGREDIENT) => {')
at('rsmanifest', 732, 'labels::DATA_HASH | labels::BMFF_HASH | labels::BOX_HASH => {')
at('rsmanifest', 735, 'label if label.starts_with(labels::CLAIM_THUMBNAIL) => {')
at('rsmanifest', 745, 'labels::ASSERTION_METADATA => {')
at('rsmanifest', 752, 'label if label.ends_with(".metadata") => {')
at('rsmanifest', 753, 'let metadata = Metadata::from_assertion(assertion)?;')
at('rsmanifest', 759, '_ => {')
at('rsmanifest', 760, '// inject assertions for all other assertions')
at('rsmanifest', 761, 'match assertion.decode_data() {')
at('rsmanifest', 762, 'AssertionData::Cbor(_) => {')
at('rsmanifest', 763, 'let value = assertion.as_json_object()?;')
at('rsmanifest', 764, 'let ma = ManifestAssertion::new(label, value)')
at('rsmanifest', 767, 'manifest.assertions.push(ma);')
at('rsmanifest', 769, 'AssertionData::Json(_) => {')
at('rsmanifest', 770, 'let value = assertion.as_json_object()?;')
at('rsmanifest', 771, 'let ma = ManifestAssertion::new(label, value)')
at('rsmanifest', 773, '.set_kind(ManifestAssertionKind::Json);')
at('rsmanifest', 775, 'manifest.assertions.push(ma);')
at('rsmanifest', 778, '// todo: support binary forms')
at('rsmanifest', 779, 'AssertionData::Binary(_x) => {}')
at('rsmanifest', 780, 'AssertionData::Uuid(_, _) => {}')
at('rsstore', 38, '#[derive(Debug, Serialize, Deserialize)]')
at('rsstore', 41, 'pub struct ManifestStore {')
at('rsstore', 47, 'manifests: HashMap<String, Manifest>,')

# --- finding 3: the JavaScript library passes the list on unfiltered
at('manifeststorets', 62, 'function parseJsonTypeHints(')
at('manifeststorets', 69, 'x.hasOwnProperty(SERDE_ARBITRARY_PRECISION_KEY)')
at('manifeststorets', 73, 'this.update(BigInt(val));')
at('manifeststorets', 75, 'this.update(parseInt(val, 10));')
at('manifeststorets', 94, 'parseJsonTypeHints(manifestStoreData),')
at('manifestts', 160, 'assertions: createAssertionAccessor(manifestData.assertions),')
ok(hits('manifestts', 'manifestdata.assertions') == [160], 'manifest.ts reads manifestData.assertions on line 160 only')
at('assertionsts', 33, 'without an index')
at('assertionsts', 48, 'const sortedAssertions = assertionData.sort(')
at('assertionsts', 49, '(a, b) => (a?.instance ?? 0) - (b?.instance ?? 0),')
at('assertionsts', 53, 'data: sortedAssertions,')
at('assertionsts', 57, 'return sortedAssertions.filter((data) => data.label === label) as any;')
ok(hits('assertionsts', '.filter(') == [57], 'assertions.ts filters in one place, the get method on line 57')

# --- finding 4: the older summary component's input type
at('l2', 35, 'export interface L2ManifestStore {')
names = [F['l2'][i - 1].strip().split(':')[0] for i in range(36, 48)]
ok(names == ['format', 'title', 'signature', 'claimGenerator', 'producer', 'socialAccounts', 'thumbnail',
             'generativeInfo', 'web3', 'isBeta', 'error', 'validationStatus'] and F['l2'][47] == '}',
   'the input type holds twelve fields, lines 36-47: ' + ', '.join(names))
at('l2', 110, 'return {')
at('l2', 111, 'manifestStore: {')
at('l2', 133, "isBeta: !!activeManifest.assertions.get('")
at('l2', 133, "')?.[0]?.data.version,")
ok(hits('l2', '.assertions') == [133], 'createL2ManifestStore.ts reads .assertions on line 133 only, with one literal label')

# --- finding 5: the popover carries no manifest data
ok(hits('popover', 'assertion', 'manifest') == [], 'Popover.ts: the words assertion and manifest do not occur')
at('popover', 43, "@customElement('cai-popover')")
at('popover', 356, '<slot name="content"></slot>')
at('popover', 361, '<slot name="trigger"></slot>')

# --- finding 6 (the handoff's inference), and the link it left unread (my addition)
at('rsstore', 198, 'async fn from_store_impl_async(')
at('rsstore', 206, 'manifest_store.active_manifest = store.provenance_label();')
at('rsstore', 213, 'let result = Manifest::from_store_async(store, manifest_label, options).await;')
at('rsstore', 217, 'match result {')
at('rsstore', 218, 'Ok(manifest) => {')
at('rsstore', 221, '.insert(manifest_label.to_owned(), manifest);')
at('rsstore', 223, 'Err(e) => {')
at('rsstore', 224, 'validation_results.add_status(ValidationStatus::from_error(&e));')
at('rsstore', 264, 'Store::load_from_memory_async(format, image_bytes, verify, &mut validation_log).await')
at('rsstore', 448, 'pub async fn from_manifest_and_asset_bytes_async(')
at('rsstore', 463, 'Ok(Self::from_store_async(store, &validation_log).await)')
ok(len(RAW['rsassertion']) == 24431, 'rs:assertion.rs at the pin: 24,431 bytes in my download (not read by the handoff)')
at('rsassertion', 282, 'pub(crate) fn decode_data(&self) -> &AssertionData {')
at('rsassertion', 283, '&self.data')
at('rsassertion', 331, 'pub(crate) fn as_json_object(&self) -> AssertionDecodeResult<Value> {')
at('rsassertion', 333, 'AssertionData::Json(x) => serde_json::from_str(x)')
at('rsassertion', 334, '.map_err(|e| AssertionDecodeError::from_assertion_and_json_err(self, e)),')
at('rsassertion', 336, 'AssertionData::Cbor(x) => {')
at('rsassertion', 341, 'serde_transcode::transcode(&mut from, &mut to)')
at('rsassertion', 342, '.map_err(|e| AssertionDecodeError::from_assertion_and_json_err(self, e))?;')
at('rsassertion', 345, 'serde_json::from_slice(&buf2)')
# the store loader at the pin tests the box before the manifest loop sees it (my addition)
ok(len(RAW['rsstorecore']) == 348123, 'rs:store.rs at the pin: 348,123 bytes in my download (not read by the handoff)')
at('rsstorecore', 796, 'let assertion = Assertion::from_data_json(&raw_label, json_box.json())?;')
at('rsstorecore', 799, 'if let Err(e) = serde_json::from_slice::<serde_json::Value>(json_box.json()) {')
at('rsstorecore', 805, '.validation_status(ASSERTION_JSON_INVALID)')
at('rsstorecore', 806, '.failure(')
at('rsstorecore', 807, 'validation_log,')
at('rsstorecore', 811, ')?;')
at('rsstorecore', 848, 'let assertion = Assertion::from_data_cbor(&raw_label, cbor_box.cbor());')
at('rsstorecore', 851, 'if let Err(e) = serde_cbor::from_slice::<serde_cbor::Value>(cbor_box.cbor()) {')
at('rsstorecore', 857, '.validation_status(ASSERTION_CBOR_INVALID)')
at('rsstorecore', 863, ')?;')
at('rsstore', 258, 'pub fn from_bytes(format: &str, image_bytes: &[u8], verify: bool) -> Result<ManifestStore> {')
at('rsstore', 259, 'let mut validation_log = StatusTracker::default();')
at('rsstore', 272, 'Ok(Self::from_store_async(store, &validation_log).await)')
at('rsstore', 275, 'Err(e) => Err(e),')
at('manifeststorets', 100, 'activeManifest: manifests[manifestStoreData.active_manifest],')
at('manifeststorets', 119, 'active_manifest: toolkitActiveManifestId,')
at('manifeststorets', 127, 'data: toolkitManifests[toolkitActiveManifestId],')
at('manifeststorets', 139, 'currentManifest?.ingredients?.forEach(')
at('manifeststorets', 158, 'const manifest = createManifest(manifestData, manifests, cawgData);')
at('manifestts', 133, 'const ingredients = manifestData.ingredients.map((ingredientData) =>')
first = [i for i in range(1, len(F['manifestts']) + 1) if 'manifestData' in F['manifestts'][i - 1] and i >= 126]
ok(first[:2] == [129, 133] and 'manifestData:' in F['manifestts'][128],
   'manifest.ts: after the parameter on line 129 the first use of manifestData is line 133 (no test for a missing value before it)')

print('%d checks, %d failed' % (n, bad))
sys.exit(1 if bad else 0)
