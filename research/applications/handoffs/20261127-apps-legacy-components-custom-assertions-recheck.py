"""Coordinator's recheck of applications item A35 (the standard's legacy web repository: do its viewer components
show an assertion with a label they do not know).

Usage: python3 -I <this file> DIR
DIR holds the coordinator's own downloads, made on 2026-11-27 with a generic User-Agent, each file in a directory of
its own: DIR/repo/repo.json, DIR/commit/commit.json, DIR/tree/tree.json (the public repository record, the pinned
commit and its recursive tree listing), DIR/wcpkg/package.json.txt, DIR/libpkg/package.json.txt, and DIR/f/NNN/
file.ts.txt for every .ts file the tree lists under the two package source directories, NNN being the file's index in
the sorted list of those paths (each fetched from the raw address of the pinned commit plus the path; no address was
guessed). The files are read as data; nothing in them is executed. Every check prints one line; the exit code is 0
only if all pass."""
import json
import re
import sys

D = sys.argv[1].rstrip('/') + '/'
C = 'c8c2912e2855c857277c0e1a6535a6db18e13c8e'
WC = 'packages/c2pa-wc/src/'
LIB = 'packages/c2pa/src/'
n = bad = 0


def ok(cond, what):
    global n, bad
    n += 1
    if not cond:
        bad += 1
    print(('ok   ' if cond else 'FAIL ') + what)


def at(p, i, sub):
    """line i (1-based) of file p contains sub"""
    line = F[p][i - 1] if 0 < i <= len(F[p]) else ''
    ok(sub in line, '%s:%d contains %r' % (p.split('/', 2)[2], i, sub) + ('' if sub in line else ' | found %r' % line[:120]))


repo = json.load(open(D + 'repo/repo.json', encoding='utf-8'))
com = json.load(open(D + 'commit/commit.json', encoding='utf-8'))
tree = json.load(open(D + 'tree/tree.json', encoding='utf-8'))

# --- the pinned source
ok(repo['archived'] is False and repo['default_branch'] == 'main', 'repository record: not archived, default branch main')
ok(repo['pushed_at'] == '2025-11-07T18:34:12Z', 'repository record: last push 2025-11-07T18:34:12Z')
ok(repo['description'] == 'JavaScript SDK for displaying and validating C2PA data', 'repository record: description as quoted')
ok(com['sha'] == C and com['commit']['committer']['date'] == '2025-11-07T18:33:42Z', 'commit: the pinned hash, committer date 2025-11-07T18:33:42Z')
ok(com['commit']['message'].startswith('Bump versions [skip ci]'), 'commit: message as quoted')
ok(tree['sha'] == C and tree['truncated'] is False and len(tree['tree']) == 495, 'tree listing: the pinned hash, not truncated, 495 entries')

blobs = {e['path']: e['size'] for e in tree['tree'] if e['type'] == 'blob'}
sel = sorted(p for p in blobs if p.startswith((WC, LIB)) and p.endswith('.ts'))
F = {}
sizes_ok = True
for i, p in enumerate(sel):
    raw = open(D + 'f/%03d/file.ts.txt' % i, 'rb').read()
    sizes_ok = sizes_ok and len(raw) == blobs[p]
    F[p] = raw.decode('utf-8').split('\n')
n_wc = sum(1 for p in sel if p.startswith(WC))
n_lib = sum(1 for p in sel if p.startswith(LIB))
ok(sizes_ok, 'every fetched source file has the size the tree listing gives')
ok(len(sel) == 78 and n_wc == 45 and n_lib == 33, 'source files fetched: 78 (45 under the web-components package source, 33 under the library source)')
ok(all(p.endswith('.ts') for p in blobs if p.startswith((WC, LIB))), 'the tree lists no file of another type under those two directories')
comp = sorted({p.split('/')[4] for p in blobs if p.startswith(WC + 'components/') and p.count('/') >= 5})
ok(len(comp) == 16, 'component directories in the tree: 16')

# --- the nine files the handoff lists, with its sizes
HS = [('packages/c2pa-wc/package.json', 3400), (WC + 'getManifestSummaryData.ts', 3856),
      (WC + 'components/ManifestSummary/ManifestSummary.ts', 9404),
      (WC + 'components/ManifestSummaryV2/ManifestSummaryV2.ts', 11508),
      (WC + 'components/MinimumViableProvenance/MinimumViableProvenance.ts', 3479),
      (LIB + 'assertions.ts', 1631), (LIB + 'manifest.ts', 4640), ('packages/c2pa/package.json', 2617),
      (LIB + 'selectors/selectEditsAndActivity.ts', 10445)]
ok(all(blobs.get(p) == s for p, s in HS), 'the nine files the handoff lists have the sizes it gives')
wcp = open(D + 'wcpkg/package.json.txt', encoding='utf-8').read().split('\n')
libp = open(D + 'libpkg/package.json.txt', encoding='utf-8').read().split('\n')
ok('"name": "c2pa-wc"' in wcp[1] and '"version": "0.14.17"' in wcp[2], 'web-components package: version 0.14.17 at line 3')
ok('"name": "c2pa"' in libp[1] and '"version": "0.30.17"' in libp[2], 'library package: version 0.30.17 at line 3')

# --- finding 1: the summary components render fixed fields
MS = WC + 'components/ManifestSummary/ManifestSummary.ts'
at(MS, 170, 'manifestStore: L2ManifestStore | undefined;')
at(MS, 209, 'const dataSelectors = {')
keys = [re.match(r'\s+(\w+):', F[MS][i]).group(1) for i in range(209, 217) if re.match(r'\s{6}(\w+):', F[MS][i])]
ok(keys == ['contentSummary', 'producedBy', 'producedWith', 'socialMedia', 'aiToolUsed', 'web3'] and F[MS][217].strip() == '};',
   'ManifestSummary.ts:209-218 the object has six keys (the handoff says 205-218; 205-207 is the value of one of them): ' + ','.join(keys))
tags = re.findall(r'<(cai-[a-z0-9-]+)', '\n'.join(F[MS][219:291]))
ok(tags == ['cai-minimum-viable-provenance', 'cai-content-summary', 'cai-produced-by', 'cai-produced-with', 'cai-social-media', 'cai-ai-tool', 'cai-web3'],
   'ManifestSummary.ts:220-291 opens seven child elements, in the order the handoff gives')
at(MS, 285, '<slot')
at(MS, 288, 'name="post"')
at(MS, 289, '@slotchange=')
V2 = WC + 'components/ManifestSummaryV2/ManifestSummaryV2.ts'
at(V2, 213, 'manifestStore: ManifestSummaryStore | undefined;')
read = re.findall(r'this\.manifestStore\.(\w+)', '\n'.join(F[V2][247:259]))
ok(sorted(set(read)) == ['doNotTrain', 'error', 'name', 'nameVerifier', 'recorder', 'socialAccounts', 'unrecordedChanges'],
   'ManifestSummaryV2.ts:248-259 reads seven fields of its input: ' + ','.join(sorted(set(read))))
ok(all(k in F[V2][263 + j] for j, k in enumerate(['ai:', "'no-ai':", "'camera-captured':", "'more-info':"])),
   'ManifestSummaryV2.ts:264-267 maps four tags to strings (the handoff says 263-268, the enclosing object)')
at(V2, 277, '<span class="header">Content Credentials</span>')
GD = WC + 'getManifestSummaryData.ts'
fields = [re.match(r'\s+(\w+):', F[GD][i]).group(1) for i in range(21, 29)]
ok(F[GD][20].startswith('export interface ManifestSummaryStore {') and F[GD][29] == '}' and
   fields == ['recorder', 'name', 'nameVerifier', 'socialAccounts', 'contentSummaryTag', 'unrecordedChanges', 'doNotTrain', 'error'],
   'getManifestSummaryData.ts:21-30 the store type has eight fields: ' + ','.join(fields))
at(GD, 82, "identity.type === 'cawg.social_media'")
at(GD, 103, "identity.type === 'cawg.document_verification'")
at(GD, 130, "return 'ai';")
at(GD, 133, 'if (false) {')
at(GD, 134, '// TODO: add camera-captured')
at(GD, 139, "return 'no-ai';")
at(GD, 142, 'if (false) {')
at(GD, 143, '// TODO: add more-info')
MV = WC + 'components/MinimumViableProvenance/MinimumViableProvenance.ts'
body = '\n'.join(F[MV][95:119])
ok('signature' in body and 'assertions' not in '\n'.join(F[MV]),
   'MinimumViableProvenance.ts:96-119 reads the signature; the file never mentions assertions')

# --- finding 2: the raw list and the fixed labels
MF = LIB + 'manifest.ts'
at(MF, 96, 'Interface providing access to assertions contained within this manifest')
at(MF, 98, 'assertions: AssertionAccessor;')
at(MF, 160, 'assertions: createAssertionAccessor(manifestData.assertions),')
AS = LIB + 'assertions.ts'
at(AS, 12, 'export interface ExtendedAssertions {}')
at(AS, 27, 'Raw assertion data as returned by the WASM binary')
at(AS, 29, 'data: Assertion[];')
at(AS, 32, 'Convenience method that returns an array of all assertions matching a given label, sorted by their index value')
at(AS, 57, 'data.label === label')
SE = LIB + 'selectors/selectEditsAndActivity.ts'
at(SE, 166, "manifest.assertions.get('com.adobe.dictionary')[0] ??")
at(SE, 167, "manifest.assertions.get('adobe.dictionary')[0];")
at(SE, 169, "const [actionsV2] = manifest.assertions.get('c2pa.actions.v2');")
at(SE, 170, "const [actionsV1] = manifest.assertions.get('c2pa.actions');")

# --- the coordinator's additions: a search of every source file, not three components
wc_hits = [(p, i + 1) for p in sel if p.startswith(WC) for i, l in enumerate(F[p]) if re.search(r'assertions|\.label\b', l)]
ok(wc_hits == [], 'no line of the 45 web-components source files contains the word assertions or reads a .label')
GET = re.compile(r"assertions\s*\??\.\s*get\(\s*'([^']+)'")
gets = {}
for p in sel:
    txt = '\n'.join(F[p])
    for m in GET.finditer(txt):
        gets.setdefault(p[len(LIB):] if p.startswith(LIB) else p, set()).add(m.group(1))
ok(sorted(gets) == ['createL2ManifestStore.ts', 'selectors/isHandmade.ts', 'selectors/selectDoNotTrain.ts',
                    'selectors/selectEditsAndActivity.ts', 'selectors/selectProducer.ts',
                    'selectors/selectSocialAccounts.ts', 'selectors/web3Info.ts'],
   'calls of assertions.get with a literal label: in seven library files (the handoff found one of them): ' + '; '.join(
       k.split('/')[-1] + ' ' + ','.join(sorted(v)) for k, v in sorted(gets.items())))
all_get_calls = sum(len(re.findall(r'assertions\s*\??\.\s*get\(', '\n'.join(F[p]))) for p in sel)
lit_get_calls = sum(len(GET.findall('\n'.join(F[p]))) for p in sel)
ok(all_get_calls == lit_get_calls, 'every call of assertions.get in the 78 files passes a literal label (%d calls)' % all_get_calls)
data_use = [(p, i + 1) for p in sel for i, l in enumerate(F[p]) if 'assertions.data' in l]
SG = LIB + 'selectors/selectGenerativeInfo.ts'
ok(data_use == [(SG, 61)], 'the raw list assertions.data is used in one place: selectGenerativeInfo.ts:61')
at(SG, 61, 'const data = manifest.assertions.data.reduce<GenerativeInfo[]>(')
at(SG, 64, "if (assertion.label === 'com.adobe.generative-ai') {")
at(SG, 80, "if (assertion.label === 'c2pa.actions') {")
at(SG, 129, "if (assertion.label === 'c2pa.actions.v2') {")
at(SG, 158, 'return acc;')
ifs = [i + 1 for i in range(60, 161) if re.match(r'\s{6}if \(assertion\.label ===', F[SG][i])]
ok(ifs == [64, 80, 129], 'selectGenerativeInfo.ts:61-161 has three label tests and then returns the accumulator unchanged (line 158): other labels add nothing')
L2 = LIB + 'createL2ManifestStore.ts'
at(L2, 35, 'export interface L2ManifestStore {')
l2f = [re.match(r'\s+(\w+):', F[L2][i]).group(1) for i in range(35, 47)]
ok(F[L2][47] == '}' and l2f == ['format', 'title', 'signature', 'claimGenerator', 'producer', 'socialAccounts', 'thumbnail',
                                 'generativeInfo', 'web3', 'isBeta', 'error', 'validationStatus'],
   'createL2ManifestStore.ts:35-48 the older component\x27s input type has twelve fields, none a list of assertions: ' + ','.join(l2f))
at(L2, 133, "isBeta: !!activeManifest.assertions.get('adobe.beta')?.[0]?.data.version,")
at(L2, 134, 'generativeInfo: selectGenerativeInfo(activeManifest),')

print('%d checks, %d failed' % (n, bad))
sys.exit(1 if bad else 0)
