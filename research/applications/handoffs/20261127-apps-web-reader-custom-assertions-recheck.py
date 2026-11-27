#!/usr/bin/env python3
"""Coordinator's recheck of applications item A32 (how the open web reader library exposes an assertion whose label it
does not know). Standard library only; nothing downloaded here is executed.

  python3 -I <this file> DIR [HANDOFF_DIR]

HANDOFF_DIR is the directory of the handoff (default: this file's own). DIR holds the coordinator's own downloads of the public files the handoff cites, one file per sub-directory:
  jsreadme webpkg reader sanitize fixture testbed typesreadme wasmreader cargo   (web library repository, commit f7c379e9...)
  manifest massertion assertion                                                  (Rust reader, commit d8d5e0ff...)
  tag tagobj jscommit jstree jsrelease                                           (public repository API, JSON)
  inspect verify                                                                 (two public pages, HTML)
Every quotation and line number of the handoff is asserted in those copies, and the handoff's own text is asserted to say
what is checked. Exit 0 only if every check passes."""
import html
import json
import os
import re
import sys

HERE = sys.argv[2].rstrip('/') if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(__file__))
D = sys.argv[1].rstrip('/') + '/'
n_checks = n_failed = 0


def check(name, cond, shown=''):
    global n_checks, n_failed
    n_checks += 1
    if not cond:
        n_failed += 1
    print('%s %s%s' % ('ok  ' if cond else 'FAIL', name, (' | ' + str(shown)) if shown != '' else ''))


def raw(key):
    d = D + key + '/'
    fs = os.listdir(d)
    assert len(fs) == 1, (key, fs)
    return open(d + fs[0], 'rb').read()


def lines(key):
    return raw(key).decode('utf-8').split('\n')


def at(key, n, sub):
    return sub in lines(key)[n - 1]


def page_text(key):
    t = raw(key).decode('utf-8', 'replace')
    t = re.sub(r'(?is)<(script|style)[^>]*>.*?</\1>', ' ', t)
    return ' '.join(html.unescape(re.sub(r'(?s)<[^>]+>', ' ', t)).split())


hb = [f for f in os.listdir(HERE) if f == '20261127-apps-web-reader-custom-assertions.md']
hand = ' '.join(open(HERE + '/' + hb[0], encoding='utf-8').read().split()) if hb else ''


def said(name, text):
    check('handoff says: ' + name, text in hand)


print('== the copies')
WEB = ['jsreadme', 'webpkg', 'reader', 'sanitize', 'fixture', 'testbed', 'typesreadme', 'wasmreader', 'cargo']
RUST, API, PAGES = ['manifest', 'massertion', 'assertion'], ['tag', 'tagobj', 'jscommit', 'jstree', 'jsrelease'], ['inspect', 'verify']
check('the directory holds 19 copies: 9 files of the web library\'s repository, 3 of the Rust reader (one not read by the handoff), '
      '5 API answers, 2 pages', sorted(os.listdir(D)) == sorted(WEB + RUST + API + PAGES)
      and (len(WEB), len(RUST), len(API), len(PAGES)) == (9, 3, 5, 2), len(os.listdir(D)))
print('== versions')
check('web library package.json line 3: version 0.17.2', at('webpkg', 3, '"version": "0.17.2"') and at('webpkg', 2, '"name": "@contentauth/c2pa-web"'))
check('workspace Cargo.toml line 10 pins the Rust reader at =0.92.2', at('cargo', 10, 'c2pa = { version = "=0.92.2"'))
jc = json.loads(raw('jscommit'))
check('web library commit f7c379e9..., committed 2026-11-23T22:30:02Z',
      jc['sha'] == 'f7c379e96f59b04ec2d358a1d517aa7aa3afe6cf' and jc['commit']['committer']['date'] == '2026-11-23T22:30:02Z')
tg, to = json.loads(raw('tag')), json.loads(raw('tagobj'))
check('Rust reader tag c2pa-v0.92.2 is an annotated tag (object bf4a48a6...) whose target is commit d8d5e0ff...',
      tg['ref'] == 'refs/tags/c2pa-v0.92.2' and tg['object']['type'] == 'tag' and tg['object']['sha'].startswith('bf4a48a6')
      and to['object']['type'] == 'commit' and to['object']['sha'] == 'd8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b',
      to['object']['sha'][:12])
rel = [r for r in json.loads(raw('jsrelease')) if r['tag_name'].startswith('@contentauth/c2pa-web@')]
check('the newest web library release in the releases list is @contentauth/c2pa-web@0.17.2',
      bool(rel) and max(rel, key=lambda r: r['published_at'])['tag_name'] == '@contentauth/c2pa-web@0.17.2',
      [r['tag_name'].split('@')[-1] for r in rel][:4])
said('versions', '`packages/c2pa-web/package.json` line 3 reads `"version": "0.17.2"`')
said('tag and commit', 'tag `c2pa-v0.92.2`, commit `d8d5e0ffb0adba8b163b8efdbd06993dbd8e0b6b`')

print('== finding 1: the web library passes the Rust reader\'s output through')
check('reader.ts 140-145 and 148-152: manifestStore() and activeManifest() return what the worker returns',
      at('reader', 140, "The asset's full {@link ManifestStore} containing all its manifests, validation statuses, and the URI of the active manifest.")
      and at('reader', 142, 'async manifestStore(): Promise<ManifestStore> {') and at('reader', 143, 'this.#worker.tx.reader_manifestStore(this.#id)')
      and at('reader', 148, "The asset's active {@link Manifest}.") and at('reader', 150, 'async activeManifest(): Promise<Manifest> {'))
check('reader.ts 166-168: crJson() exists', at('reader', 166, "The asset's manifest store as crJSON.") and at('reader', 168, 'async crJson(): Promise<any> {'))
check('wasm_reader.rs 167-171 and 181-187: the reader is serialised as it is',
      at('wasmreader', 168, 'Serializer::new().serialize_maps_as_objects(true)') and at('wasmreader', 181, 'pub fn manifest_store(&self)')
      and at('wasmreader', 184, '.serialize(&self.serializer)'))
san = '\n'.join(lines('sanitize'))
check('sanitizeManifestStore.ts 11-12 and 28-43: only the manifests map is rebuilt; the word "assertion" is not in the file',
      at('sanitize', 11, "Rebuilds the manifest store's manifests map as a null-prototype object so")
      and at('sanitize', 12, 'that reserved property names like "__proto__" are safe to use as keys.')
      and at('sanitize', 28, 'export function sanitizeManifestStore(store: any): any {') and 'assertion' not in san.lower())
check('types README 3 and 25-27: the types are generated from the Rust structs',
      at('typesreadme', 3, 'auto-generated from [c2pa-rs]') and at('typesreadme', 25, 'schemar') and at('typesreadme', 27, 'json-schema-to-typescript'))

print('== finding 2: an unknown label is returned when its data is CBOR or JSON')
check('manifest.rs 551 and 554: the loop matches on the assertion\'s base label',
      at('manifest', 551, 'let base_label = assertion.label();') and at('manifest', 554, 'match base_label.as_ref() {'))
check('manifest.rs known arms: actions 555, ingredient 596, thumbnail 609, assertion metadata 614, ".metadata" 622, identity 632; hashes left out at 607',
      at('manifest', 555, 'base.starts_with(labels::ACTIONS)') and at('manifest', 596, 'base.starts_with(labels::INGREDIENT)')
      and at('manifest', 609, 'label.starts_with(labels::CLAIM_THUMBNAIL)') and at('manifest', 614, 'labels::ASSERTION_METADATA =>')
      and at('manifest', 622, 'label if label.ends_with(".metadata") =>') and at('manifest', 632, 'label == "cawg.identity"')
      and at('manifest', 607, '// do not include data hash when reading manifests'))
check('manifest.rs 669-670: the catch-all arm, "inject assertions for all other assertions"',
      at('manifest', 669, '_ => {') and at('manifest', 670, '// inject assertions for all other assertions'))
check('manifest.rs 672-678: CBOR data is converted and pushed under the base label',
      at('manifest', 672, 'AssertionData::Cbor(_) => {') and at('manifest', 673, 'let value = assertion.as_json_object()?;')
      and at('manifest', 674, 'ManifestAssertion::new(base_label.clone(), value)') and at('manifest', 678, 'manifest.assertions.push(ma);'))
check('manifest.rs 680-688: the same for JSON data, with kind Json',
      at('manifest', 680, 'AssertionData::Json(_) => {') and at('manifest', 684, '.set_kind(ManifestAssertionKind::Json)')
      and at('manifest', 687, 'manifest.assertions.push(ma);'))
check('manifest.rs 690-692: binary and UUID data add nothing ("todo: support binary forms")',
      at('manifest', 690, '// todo: support binary forms') and at('manifest', 691, 'AssertionData::Binary(_x) => {}')
      and at('manifest', 692, 'AssertionData::Uuid(_, _) => {}'))
check('manifest.rs 100 and manifest_assertion.rs 37-51: the returned object is label, data, instance, kind, created',
      at('manifest', 100, 'pub(crate) assertions: Vec<ManifestAssertion>,') and at('massertion', 37, 'pub struct ManifestAssertion {')
      and at('massertion', 38, '/// An assertion label in reverse domain format') and at('massertion', 39, 'label: String,')
      and at('massertion', 41, 'pub(crate) data: ManifestData,') and at('massertion', 44, 'instance: Option<usize>,')
      and at('massertion', 47, 'kind: Option<ManifestAssertionKind>,') and at('massertion', 48, '/// True if this assertion is attributed to the signer')
      and at('massertion', 51, 'created: bool,'))
check('the web library\'s test fixture 34, 48-52, 61: three labels expected, two outside the standard\'s own namespace',
      at('fixture', 34, "label: 'c2pa.actions.v2'") and at('fixture', 48, "label: 'cawg.training-mining'")
      and at('fixture', 52, "use: 'notAllowed'") and at('fixture', 61, "label: 'cawg.identity'"))
said('the catch-all lines', 'Line 669 `_ => {` with the comment, line 670: "inject assertions for all other assertions"')
said('binary and UUID dropped', '`AssertionData::Binary(_x) => {}` and `AssertionData::Uuid(_, _) => {}`: nothing is added')

print('== finding 3: no interface component in this repository')
tr = [e['path'] for e in json.loads(raw('jstree'))['tree']]
pk = sorted({p.split('/')[1] for p in tr if p.startswith('packages/') and p.count('/') >= 2})
tl = sorted({p.split('/')[1] for p in tr if p.startswith('tools/') and p.count('/') >= 2})
check('tree listing: five packages and two tools, none a viewer or web-component package',
      pk == ['c2pa-node', 'c2pa-types', 'c2pa-utilities', 'c2pa-wasm', 'c2pa-web'] and tl == ['nx-wasm-bindgen', 'testbed']
      and not json.loads(raw('jstree')).get('truncated'), pk + tl)
check('package.json 56-61: four dependencies, none an interface library',
      at('webpkg', 56, '"dependencies": {') and at('webpkg', 57, '"@contentauth/c2pa-types"') and at('webpkg', 58, '"@contentauth/c2pa-utilities"')
      and at('webpkg', 59, '"@contentauth/c2pa-wasm"') and at('webpkg', 60, '"highgain"') and at('webpkg', 61, '},'))
check('root README 17: the old repository is deprecated',
      at('jsreadme', 17, 'The old `c2pa-js` repository is now in [c2pa-js-legacy](https://github.com/contentauth/c2pa-js-legacy) and is deprecated.'))
check('testbed main.ts 16-19, 50-51, 55: the sample reads and logs, it renders nothing',
      at('testbed', 17, 'verify: { verifyTrust: false },') and at('testbed', 18, 'cawgTrust: { verifyTrustList: false }')
      and at('testbed', 50, 'const reader = await Reader.fromBlob(c2pa, file.type, file, context);')
      and at('testbed', 51, 'const manifestStore = await reader?.manifestStore();') and at('testbed', 55, 'console.log(manifestStore);'))

print('== finding 4: the two public pages')
vt = page_text('verify')
check('the public Verify page is a 3,246-byte shell whose only text asks for JavaScript',
      len(raw('verify')) == 3246 and vt == 'Content Credentials Please enable Javascript to use this site.', vt)
it = page_text('inspect')
check('the inspection tool\'s page: "a C2PA conforming validator product that can display and apply Content Credentials for various asset types"',
      'is a C2PA conforming validator product that can display and apply Content Credentials for various asset types' in it)
check('the inspection tool\'s page lists four subsections of content details',
      'divided into the following subsections: App or device used Recorded by Actions Ingredients' in it)
check('the inspection tool\'s page: the message for an asset with no manifest store',
      'Does not have an associated manifest store, Inspect displays the message No Content Credential' in it)
occ = [m.start() for m in re.finditer('assertion', it.lower())]
check('on that page the word "assertion" occurs only inside addresses of the sample JSON',
      len(occ) > 0 and all(it.lower()[o - 4:o + 20].startswith('cai-assertions.') for o in occ), len(occ))
check('that page shows no version; its footer carries the year 2026', 'Copyright © 2026' in it)

print('== MINE: the coordinator\'s remarks')
check('MINE 1: the ".metadata" arm is at manifest.rs 622-629, not "line 63-70" as the handoff\'s caveat has it',
      at('manifest', 622, 'label if label.ends_with(".metadata") =>') and at('manifest', 623, 'Metadata::from_assertion(assertion)?')
      and at('manifest', 629, '}') and 'decoded as a Metadata assertion (line 63-70)' in hand)
check('MINE 2: a CBOR byte string comes back as base64 text, not as bytes (assertion.rs 338-341; the library\'s own test 709-730, '
      'on the label "test.bytes_and_array")',
      at('assertion', 338, 'AssertionData::Cbor(x) => {') and at('assertion', 341, 'Ok(cbor_to_json_b64(value))')
      and at('assertion', 709, 'fn test_cbor_bytes_vs_int_array_json_b64_encoding()')
      and at('assertion', 722, 'Assertion::new("test.bytes_and_array", None, data);')
      and at('assertion', 726, '// A genuine CBOR byte string (major type 2) uses a json_b64 byte marker.')
      and at('assertion', 729, 'encode_b64_wrapped(&[1, 2, 3, 4])'))
check('MINE 3: CBOR that does not parse is an error at assertion.rs 339-340, and manifest.rs 673 passes it up with "?"; what the '
      'caller then does was not read',
      at('assertion', 339, 'c2pa_cbor::from_slice(x)') and at('assertion', 340, 'AssertionDecodeError::from_assertion_and_cbor_err(self, e))?;')
      and at('manifest', 673, 'assertion.as_json_object()?;'))
check('MINE 4: the returned entry also says whether the signer created the assertion (manifest.rs 552, 676)',
      at('manifest', 552, 'ClaimAssertionType::Created') and at('manifest', 676, '.set_created(created);'))
print('checks: %d, failed: %d' % (n_checks, n_failed))
sys.exit(1 if n_failed else 0)
