"""Coordinator's reading for what was left of applications item A42: which error name the legacy JavaScript library's
`read` sees when a custom assertion's JSON box is not UTF-8, whether that name can be one of the three it ignores, how
the name crosses the library's worker, and one more exit found on the way (an assertion whose data box is absent or of
another kind).

Usage: python3 -I <this file> DIR_A39 DIR_A42
DIR_A39 holds the coordinator's downloads made for item A39 (DIR_A39/<key>/file.txt; six of them are used here and
compared with the table of sizes and hashes in A39's handoff, which lies beside this script). DIR_A42 holds nine more
files downloaded on 2026-11-27 with a generic User-Agent from the raw address of the same two pinned commits, each in
a directory of its own; their lengths and hashes are written below. The files are read as data; nothing in them is
executed. Every check prints one line; the exit code is 0 only if all pass."""
import hashlib
import os
import re
import sys

D39 = sys.argv[1].rstrip('/') + '/'
D42 = sys.argv[2].rstrip('/') + '/'
CR = '0a29852b0546596972c7105a7a510b12e050dc67'
CJ = 'c8c2912e2855c857277c0e1a6535a6db18e13c8e'
OLD = {'store': 'sdk/src/store.rs', 'assertion': 'sdk/src/assertion.rs', 'rsstore': 'sdk/src/manifest_store.rs',
       'c2pa': 'packages/c2pa/src/c2pa.ts', 'lib': 'packages/toolkit/src/lib.rs',
       'tkstore': 'packages/toolkit/src/manifest_store.rs'}
NEW = {'rserror': ('sdk/src/error.rs', 13173, '941810ac432cd9afcc0954bace5f2c7d84f53aaf88e70f916648638585a9b71f'),
       'boxes': ('sdk/src/jumbf/boxes.rs', 93177, 'c3ffef224dafb4d415eaa603157dd4806b2fc3bf6886fdbb7fca16237abfd6dd'),
       'tkerror': ('packages/toolkit/src/error.rs', 529, '4312172175d62d98606b695ec1bc3845b9d3182af01d0441f86098bb8ad39950'),
       'wentry': ('packages/c2pa/worker.ts', 1713, '2d24ed71000403bbd8517a4c4924a9580e909daa9a6332a6f9423002031aabc2'),
       'plworker': ('packages/c2pa/src/lib/pool/worker.ts', 1080, 'a9d1882d86e3d89bb4188666fbf205cb8d081ac1cff96282ad9031ad6087a178'),
       'plerror': ('packages/c2pa/src/lib/pool/error.ts', 995, '5a7fac54d27df0dd192103a6299e26f896a0ee3bc38ab11131e19dded2b7d13f'),
       'plmanager': ('packages/c2pa/src/lib/pool/workerManager.ts', 1464, '11bb597f7b15e1caee708b140a76bb03e0f13db192665b8ea56e5912bb363e7e'),
       'plpool': ('packages/c2pa/src/lib/pool/workerPool.ts', 2712, '61fec47432d2e88229a6898ee424e7ca384848691bbca6dc20edbd21357635ee'),
       'plwrap': ('packages/c2pa/src/lib/poolWrapper.ts', 1614, '39d1b07db84abcb15886993c745734c14920a6ebbac092cc9668cb87fd6dbbcf')}
HAND = open(os.path.dirname(os.path.abspath(__file__)) + '/20261127-apps-legacy-malformed-assertion.md', encoding='utf-8').read()
n = bad = 0


def ok(cond, what):
    global n, bad
    n += 1
    if not cond:
        bad += 1
    print(('ok   ' if cond else 'FAIL ') + what)


F = {}
PATHS = dict(OLD)
same = True
for k, p in OLD.items():
    raw = open(D39 + k + '/file.txt', 'rb').read()
    same = same and ('| `%s` | %d | %s |' % (p, len(raw), hashlib.sha256(raw).hexdigest())) in HAND
    F[k] = raw.decode('utf-8').split('\n')
ok(same and CR in HAND and CJ in HAND, 'the six files re-used from item A39 have the byte length and SHA-256 its handoff lists, at the two pinned commits')
same = True
for k, (p, size, h) in NEW.items():
    raw = open(D42 + k + '/file.txt', 'rb').read()
    same = same and len(raw) == size and hashlib.sha256(raw).hexdigest() == h
    PATHS[k] = p
    F[k] = raw.decode('utf-8').split('\n')
ok(same, 'the nine further files have the lengths and hashes written in this script')


def short(k):
    p = PATHS[k]
    if p.startswith('sdk/src/'):
        return p[8:]
    return p.split('/', 1)[1] if p.startswith('packages/') else p


def at(k, i, sub):
    line = F[k][i - 1] if 0 < i <= len(F[k]) else ''
    ok(sub in line, '%s:%d contains %r' % (short(k), i, sub) + ('' if sub in line else ' | found %r' % line[:120]))


def fn_above(k, i):
    for j in range(i - 1, -1, -1):
        m = re.search(r'\bfn\s+([a-z_0-9]+)', F[k][j])
        if m:
            return j + 1, m.group(1)
    return 0, ''


print('-- 1. the error of a JSON box that is not UTF-8, from where it is made to the name set on the JavaScript error')
at('assertion', 438, 'pub(crate) fn from_data_json(')
at('assertion', 442, 'let json = String::from_utf8(binary_data.to_vec()).map_err(|_| AssertionDecodeError {')
at('assertion', 444, 'version: None,')
at('assertion', 445, 'content_type: "json".to_string(),')
at('assertion', 446, 'source: AssertionDecodeErrorCause::BinaryDataNotUtf8,')
at('store', 760, ') -> Result<ClaimAssertion> {')
at('store', 796, 'let assertion = Assertion::from_data_json(&raw_label, json_box.json())?;')
ok(fn_above('store', 796) == (754, 'get_assertion_from_jumbf_store'), 'store.rs:796 is inside get_assertion_from_jumbf_store, which opens at 754')
at('rserror', 21, '#[derive(Debug, Error)]')
at('rserror', 23, 'pub enum Error {')
at('rserror', 42, 'AssertionDecoding(#[from] crate::assertion::AssertionDecodeError),')
ok([i + 1 for i, l in enumerate(F['rserror']) if 'AssertionDecodeError' in l] == [42],
   'error.rs names AssertionDecodeError on line 42 only, so the conversion at store.rs:796 is the derived one into AssertionDecoding')
impls = [i + 1 for i, l in enumerate(F['rserror']) if l.startswith('impl')]
ok(impls == [369, 390, 410, 417] and not any('Assertion' in F['rserror'][i - 1] for i in impls),
   'error.rs has four hand-written impl blocks (369, 390, 410, 417) and none is about an assertion error')
at('store', 1370, 'match Store::get_assertion_from_jumbf_store(')
at('store', 1383, 'if std::mem::discriminant(&e)')
at('store', 1384, '== std::mem::discriminant(&Error::PrereleaseError)')
at('store', 1391, 'return Err(e);')
ok(fn_above('store', 1391) == (1126, 'from_jumbf'), 'store.rs:1391 is inside from_jumbf, which opens at 1126')
at('store', 3968, '.map(|(manifest_bytes, _)| Store::from_jumbf(&manifest_bytes, validation_log))?')
at('store', 4143, 'Self::load_cai_from_memory(asset_type, data, validation_log).inspect_err(|e| {')
at('store', 4355, 'let store = Store::get_store_from_memory(asset_type, data, validation_log)?;')
ok(fn_above('store', 4355) == (4349, 'load_from_memory_async'), 'store.rs:4355 is inside load_from_memory_async, which opens at 4349')
at('rsstore', 264, 'Store::load_from_memory_async(format, image_bytes, verify, &mut validation_log).await')
at('rsstore', 275, 'Err(e) => Err(e),')
at('rsstore', 454, 'let store = Store::from_jumbf(manifest_bytes, &mut validation_log)?;')
at('tkstore', 18, 'ManifestStore::from_bytes_async(mime_type, data, true)')
at('tkstore', 20, '.map_err(Error::from)')
at('tkstore', 32, 'ManifestStore::from_manifest_and_asset_bytes_async(manifest_bytes, format, asset_bytes)')
at('tkstore', 34, '.map_err(Error::from)')
at('tkerror', 9, '#[derive(Error, Debug)]')
at('tkerror', 10, 'pub enum Error {')
at('tkerror', 18, 'C2pa(#[from] c2pa::Error),')
at('lib', 65, 'let js_err = JsSysError::new(&err.to_string());')
at('lib', 66, 'js_err.set_name(&format!("{:?}", err));')
at('lib', 68, 'if let Error::C2pa(c2pa::Error::RemoteManifestUrl(url)) = err {')
at('lib', 69, 'js_err.set_name("Toolkit(RemoteManifestUrl)");')
at('lib', 99, 'let result = get_manifest_store_data(&asset, &mime_type, settings.as_deref())')
at('lib', 101, '.map_err(as_js_error)?;')
at('lib', 132, '.map_err(as_js_error)?;')

print('-- 2. the text of that name')
at('assertion', 598, 'impl std::fmt::Debug for AssertionDecodeError {')
at('assertion', 600, 'self.fmt_internal(f)')
at('assertion', 511, '"could not decode assertion {} (version {}, content type {}): {}",')
at('assertion', 514, '.map_or("(no version)".to_string(), |v| v.to_string()),')
at('assertion', 516, 'self.source')
at('assertion', 630, '#[error("binary data could not be interpreted as UTF-8")]')
at('assertion', 631, 'BinaryDataNotUtf8,')


def name_for(label):
    inner = 'could not decode assertion %s (version (no version), content type json): binary data could not be interpreted as UTF-8' % label
    return 'C2pa(AssertionDecoding(%s))' % inner


at('c2pa', 291, '/^C2pa\\(ProvenanceMissing\\)$/,')
at('c2pa', 293, '/^C2pa\\(JumbfParseError\\([^\\)]+\\)\\)$/,')
at('c2pa', 295, '/^C2pa\\(Jumbf(?:Box)?NotFound\\)$/,')
src = [F['c2pa'][i - 1].strip() for i in (291, 293, 295)]
pats = [re.compile(s[1:s.rindex('/')]) for s in src]
ok(sum(1 for i in range(288, 296) if F['c2pa'][i].strip().startswith('/^')) == 3, 'the ignore list at c2pa.ts 289-296 has exactly these three patterns')
ok(all(p.pattern.startswith('^C2pa\\(') and p.pattern[7] in 'PJ' for p in pats) and name_for('x')[5] == 'A',
   'each ignored pattern requires P or J right after "C2pa(" and the derived name has A there, so no assertion label can make it match')
labels = ['org.example.proof', 'x', 'JumbfBoxNotFound)', 'ProvenanceMissing)', 'a) (b', '']
ok(not any(p.match(name_for(l)) for p in pats for l in labels) and all(name_for(l) != 'Toolkit(RemoteManifestUrl)' for l in labels),
   'for six sample labels the derived name matches none of the three patterns and is not the remote-manifest name')
print('     derived name for the label org.example.proof: ' + name_for('org.example.proof'))
at('c2pa', 318, "if (error.name === 'Toolkit(RemoteManifestUrl)') {")
at('c2pa', 325, 'if (ignoreErrors.some((re) => re.test(error.name))) {')
at('c2pa', 327, 'return null;')
at('c2pa', 330, 'throw error;')

print('-- 3. how the error and its name cross the worker')
at('wentry', 32, 'async getReport(')
at('wentry', 39, 'return getManifestStoreFromArrayBuffer(buffer, type, settings);')
ok(not any('try' in F['wentry'][i] or 'catch' in F['wentry'][i] for i in range(31, 40)), 'worker.ts 32-40: getReport has no try or catch of its own')
at('plworker', 35, 'const res = await methods[method](...args);')
at('plworker', 41, '} catch (error: unknown) {')
at('plworker', 44, 'error: serializeError(error as Error),')
at('plerror', 16, 'return Object.getOwnPropertyNames(error).reduce(function (product, name) {')
at('plerror', 18, 'value: error[name],')
at('plerror', 26, "var temp = new Error('');")
at('plerror', 31, 'temp[props[i]] = serializedError[props[i]];')
at('plmanager', 38, 'reject(deserializeError(e.data.error));')
at('plpool', 68, 'const result = await worker.execute(task.request);')
at('plpool', 71, 'task.reject(error);')
at('plpool', 95, 'reject(value);')
at('plwrap', 42, "getReport: async (...args) => workerPool.execute('getReport', args),")
at('c2pa', 237, 'const result = await pool.getReport(wasm, buffer, source.type, settings);')
at('c2pa', 246, '} catch (err: any) {')
at('c2pa', 247, 'const manifestStore = await handleErrors(')

print('-- 4. one more exit: an assertion whose data box is absent or of another kind')
end = next(i for i in range(754, len(F['store'])) if re.match(r'    (pub(\([a-z]+\))? )?(async )?fn ', F['store'][i]))
ok([i + 1 for i in range(753, end) if 'JumbfBoxNotFound' in F['store'][i]] == [794, 827, 830, 847, 879],
   'inside get_assertion_from_jumbf_store (754 to %d) the lines that name JumbfBoxNotFound are 794, 827, 830, 847 and 879' % end)
for i in (794, 827, 830, 847, 879):
    at('store', i, '.ok_or(Error::JumbfBoxNotFound)?;')
at('store', 791, 'CAI_JSON_ASSERTION_UUID => {')
at('store', 793, '.data_box_as_json_box(0)')
at('store', 844, 'CAI_CBOR_ASSERTION_UUID => {')
at('boxes', 295, 'pub fn data_box_as_json_box(&self, index: usize) -> Option<&JUMBFJSONContentBox> {')
at('boxes', 296, 'self.data_boxes.get(index).and_then(|da_box| {')
at('boxes', 300, '.downcast_ref::<JUMBFJSONContentBox>()')
at('boxes', 304, 'pub fn data_box_as_cbor_box(&self, index: usize) -> Option<&JUMBFCBORContentBox> {')
at('boxes', 309, '.downcast_ref::<JUMBFCBORContentBox>()')
at('rserror', 202, 'JumbfNotFound,')
at('rserror', 205, 'JumbfBoxNotFound,')
at('rserror', 260, 'ProvenanceMissing,')
at('rserror', 278, 'JumbfParseError(#[from] crate::jumbf::boxes::JumbfParseError),')
ok(pats[2].match('C2pa(JumbfBoxNotFound)') is not None and not pats[0].match('C2pa(JumbfBoxNotFound)') and not pats[1].match('C2pa(JumbfBoxNotFound)'),
   'the name C2pa(JumbfBoxNotFound) matches the third ignored pattern (and only that one), so handleErrors returns null at line 327')
at('c2pa', 256, 'return {')
at('c2pa', 257, 'manifestStore,')

print('%d checks, %d failed' % (n, bad))
sys.exit(1 if bad else 0)
