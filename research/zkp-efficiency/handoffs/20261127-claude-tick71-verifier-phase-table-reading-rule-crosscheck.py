"""Coordinator's cross-check of research tick 71 (2026-11-27): the command, the inputs and the table counts for a
one-thread run of the classifier's verifier at the installed profile. Standard library only; reads source text, three
records and file hashes; runs nothing of the prover and writes nothing.

Usage: python3 -I <this file>
"""
import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))) + '/'
HOME = os.path.expanduser('~') + '/'
PB = 'ops/zkp-mvp/gpu-metal/hashline/src/private_block/'
N = [0, 0]


def check(ok, text):
    N[0] += 1
    if not ok:
        N[1] += 1
    print(('ok   ' if ok else 'FAIL ') + text)


def lines(path):
    return open(ROOT + path, encoding='utf-8', errors='replace').read().split('\n')


def at(path, n, sub):
    return sub in lines(path)[n - 1]


def find(path, sub):
    return [i + 1 for i, l in enumerate(lines(path)) if sub in l]


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


# ---------------------------------------------------------------- the command and what it touches
CLI = PB + 'token_io/classify_cli.rs'
check(at(PB + 'token_io/classify_run.rs', 1014, 'ph.report("verify"'),
      "the classifier run's verifier reports its phase recorder after a block (classify_run.rs:1014)")
check(at(CLI, 1283, '&["--export", "--tables", "--policy", "--artifact", "--expect-statement", "--label", "--min-bits"], &[w16r2::DEV_W16R2_SWITCH]'),
      'verify takes seven flags and the W16R2 development switch (classify_cli.rs:1283)')
check(at(PB + 'token_io/classify_w16r2.rs', 36, 'pub(crate) const DEV_W16R2_SWITCH: &str = "--dev-w16r2-public-content-only";'),
      'the switch is --dev-w16r2-public-content-only (classify_w16r2.rs:36)')
check(at(CLI, 1299, 'clear_stale_writing_dirs(&art)?;') and at(CLI, 1301, 'if !c.published {')
      and at(CLI, 1305, 'publish_statement_dir(&art,') and at(CLI, 1308, 'std::fs::remove_dir_all(&unverified)'),
      'verify clears stale writing directories of the run directory, and publishes a statement when none is published '
      '(classify_cli.rs:1299-1308): a run on a copy leaves the original untouched')
check(at(CLI, 1207, 'println!("PB-CLI verify | the run (verify_classify_run_with) | {verify_s:.3} s");'),
      'with timing on, verify prints the whole run as one PB-CLI line (classify_cli.rs:1207)')
AV = 'apps/proven-media/proven_media/w16r2_public_verifier.py'
n = find(AV, 'NEED_GIB, CAP_GIB, MAX_SECONDS = 12, 16, 900')
g = find(AV, "return ['python3', str(config.GUARD), 'run', '--class', 'gpu', '--need-gib', str(NEED_GIB),")
a = find(AV, "'--expect-statement', intake['statement_identity'], '--min-bits', '95', w16.FLAG]")
check(len(n) == 1 and len(g) == 1 and len(a) == 1 and a[0] == g[0] + 6,
      "the app's own verifier call: guard class gpu, 12 GiB asked, 16 GiB cap, 900 s, the same seven flags and the "
      'switch (w16r2_public_verifier.py:%d, %d-%d)' % (n[0], g[0], a[0]))
D = json.load(open(ROOT + 'apps/proven-media/deploy.json'))['classifier_profiles']['shieldstral-mac-fast-w16r2']
check(D['min_bits'] == 95 and D['servers']['check_lane_threads'] == 4 and str(D['native_settings']['HL_A26_VERIFY_ONCE']) == '0',
      "the app's profile: min bits 95, four threads a check lane, HL_A26_VERIFY_ONCE 0 (deploy.json)")
check(D['privacy_status'] == 'Public content only; privacy not claimed' and D['production'] is False,
      'the profile says: public content only, privacy not claimed, not production (deploy.json)')

# ---------------------------------------------------------------- the pool, and the refusal log
sites = []
for base in ('ops/zkp-mvp/gpu-metal/hashline/src/', 'ops/zkp-mvp/gpu-metal/zkp-core/src/'):
    for d, _, fs in os.walk(ROOT + base):
        for f in sorted(fs):
            if f.endswith('.rs') and not f.endswith('tests.rs'):
                p = os.path.join(d, f)[len(ROOT):]
                sites += [(p[len('ops/zkp-mvp/gpu-metal/'):], i) for i in find(p, 'ThreadPoolBuilder::new()')]
want = [('hashline/src/bin/hashline.rs', 211), ('hashline/src/private_block/run_fork.rs', 1287),
        ('hashline/src/private_block/run_fork.rs', 2030), ('hashline/src/private_block/token_io/classify_serve.rs', 308),
        ('hashline/src/private_block/trained_block.rs', 2561), ('hashline/src/private_block/trained_block.rs', 5987),
        ('zkp-core/src/transcript.rs', 403)]
check(sorted(sites) == sorted(want), 'thread pools are built in seven places outside the test files: %d found' % len(sites))
TB = PB + 'trained_block.rs'
check(at(TB, 5978, 'expect("honest seal_chain with W2 on")') and at(TB, 5992, 'crate::zk::set_host_fast_w2_for_test(Some(w2_on));')
      and at('ops/zkp-mvp/gpu-metal/zkp-core/src/transcript.rs', 294, '#[cfg(test)]')
      and at('ops/zkp-mvp/gpu-metal/zkp-core/src/transcript.rs', 295, 'mod tests {'),
      'two of the seven are inside test code (trained_block.rs:5987, transcript.rs:403)')
check(at(TB, 2561, 'thread_name(move |i| format!("hl-seal{t}-{i}"))') and at(PB + 'run_fork.rs', 1287, 'hl-fork{w}-pool{i}')
      and at('ops/zkp-mvp/gpu-metal/hashline/src/bin/hashline.rs', 211, 'build_global()'),
      'the other five are the sealing pool, the two fork pools, the servers\' lanes and another binary\'s global pool: '
      'none is on the path of the verify command, which therefore runs on the default global pool')
v = find(TB, 'if let Some(d) = std::env::var_os("HL_OWNER_PRIVATE_DIR") {')
w = find(TB, 'std::env::var_os("HOME").map(|h| PathBuf::from(h).join("zk60-owner-private"))')
k = find(TB, '/// verifier refusals (about public receipts) keep their text.')
check(len(v) == 1 and len(w) == 1 and len(k) == 1 and v[0] < w[0],
      'a refusal detail is logged under HL_OWNER_PRIVATE_DIR when set, else under the home directory; verifier refusals '
      'keep their text (trained_block.rs:%d, %d, %d). A run of mine sets the variable to a scratch directory' % (k[0], v[0], w[0]))

# ---------------------------------------------------------------- the inputs on this machine
BIN = HOME + 'zk60-artifacts/proven-media-fast/bin/zk60_classify.a30a31'
ART = HOME + 'zk60-artifacts/astra-merged-w16r2-slget05j/'
EXP = ART + 'verifier-export-w16r2-94643880/'
check(os.path.isfile(BIN) and sha(BIN) == D['binary_sha256'],
      "the file zk60_classify.a30a31 has the SHA-256 that the app's profile pins for its verifier binary")
check(sha(EXP + 'profile.json') == D['profile_sha256'] and not any(x.startswith('seq_') for x in os.listdir(EXP))
      and os.path.isdir(EXP + 'token_io'),
      "the verifier export's profile.json has the pinned SHA-256; the export has a token_io directory and no seq_ entry")
runs = sorted(os.listdir(ART + 'runs'))
ok, tot = True, set()
pols = []
for r in runs:
    segs = sorted(x for x in os.listdir(ART + 'runs/' + r) if re.fullmatch(r'segment-\d{3}\.bin', x))
    st = open(ART + 'runs/' + r + '/statement/statement.json', encoding='utf-8').read()
    ok = ok and len(segs) == 28 and D['statement_identity'] in st and 'w16r2-dev-only/2' in st
    tot.add(sum(os.path.getsize(ART + 'runs/' + r + '/' + s) for s in segs))
    pols += re.findall(r'shieldstral-1\.0-3b-moderate-[a-z]+/1', st)[:1]
check(len(runs) == 3 and ok, 'three retained runs, each with 28 segments and a published statement that names the pinned '
      'identity and the W16R2 development run profile')
check(tot == {669561472}, 'each run\'s 28 segments total 669,561,472 bytes, the receipt size the status page states: %s' % sorted(tot))
check(sorted(pols) == ['shieldstral-1.0-3b-moderate-hate/1', 'shieldstral-1.0-3b-moderate-sexual/1',
                       'shieldstral-1.0-3b-moderate-violence/1'], 'their policies are the three categories: %s' % sorted(pols))
check(os.path.isdir(ROOT + 'results/zk60_astra_20261026/flashprove_runtime_20261104/models'),
      'the models directory the handoff names exists')

# ---------------------------------------------------------------- table counts and sizes
RAW = 'results/zk60_w16r2_shield_block_20261120/raw/'


def tabs(path):
    build, cube = {}, {}
    for l in lines(path):
        m = re.match(r'PB-SLOTSTEP slot (\d+) \| (tables: build|claimed sum: total) \(argument\.rs\)\s*\|\s*[0-9.]+ s \|\s*(\d+) \|', l)
        if m:
            (build if m.group(2).startswith('tables') else cube).setdefault(int(m.group(1)), int(m.group(3)))
    return {s: (build[s] // cube[s], cube[s]) for s in build if s in cube and build[s] % cube[s] == 0}


t8, ti = tabs(RAW + 'w16r2_8b_ctl.log'), tabs(RAW + 'w16r2_shield_a1.log')
diff = {s: (t8[s], ti[s]) for s in t8 if t8[s] != ti[s]}
check(len(t8) == 23 and len(ti) == 23 and sorted(diff) == [0, 1, 14]
      and all(ti[s] == (t8[s][0] + 1, 1 << 19) for s in diff),
      'prover logs of 20 November: the installed profile has one table more than the 8B profile at slots 0, 1 and 14, '
      'each on a cube of 2^19, and the same counts and cubes at the other twenty slots')
AA = PB + 'argument_accuracy.rs'
AR = PB + 'argument.rs'
check(at(AR, 2579, 'fn supp(&mut self, dom: Dom, cube_len: usize) -> Result<Option<usize>, String> {')
      and at(AR, 2581, 'if !sh.carries_pad_rule() || !sh.pads(dom) {') and at(AR, 2582, 'return Ok(None);')
      and at(AR, 2989, 'let supp = b.supp(Dom::D, cube)?;') and at(AR, 3029, 'let supp = b.supp(Dom::D, cube)?;')
      and at(AA, 478, 'let gd=Gate(b.supp(Dom::D,cube)?);'),
      'the code gives a support table of D only where D pads, and asks for it at three slot definitions '
      '(argument.rs:2579-2582, 2989, 3029; argument_accuracy.rs:478)')
check(8052736 + 3 * (1 << 19) == 9625600 and round(9625600 / 8052736, 3) == 1.195,
      'public entries a block at the installed profile: 8,052,736 + 3 x 2^19 = 9,625,600, 1.195 times the 8B count')
exp = {s: 2 * ti[s][0] * ti[s][1] for s in (0, 1, 4, 14, 15, 16, 17, 18, 19)}
check(exp == {0: 3145728, 1: 3145728, 4: 4194304, 14: 38797312, 15: 15728640, 16: 3932160, 17: 19922944, 18: 79691776, 19: 1900544},
      'twice tables times cube at the installed profile gives the sizes the handoff expects a verifier table to print')

# ---------------------------------------------------------------- the verifier log of 7 November (R13 profile)
LOG = 'results/zk60_a24_app_20261107/baseline_b1_cpu_verify.log'
T, cur = [], None
for l in lines(LOG):
    if l.startswith('PB-TIMING verify [') and 'phases, wall' in l:
        cur = {'head': l, 'rows': []}
        T.append(cur)
    elif cur is not None and l.startswith('PB-TIMING verify | ') and l.count('|') >= 6:
        c = [x.strip() for x in l.split('|')]
        if re.fullmatch(r'[0-9.]+', c[3]) and c[1] not in ('SUM OF PHASES', 'WALL CLOCK OF THE CALL') and not c[1].startswith('unaccounted'):
            cur['rows'].append((c[1], float(c[3]), c[5], c[8]))
check(len(T) == 26 and all(len(t['rows']) == 30 for t in T) and all('r13-public-row/2' in t['head'] for t in T),
      'the 7 November verifier log: 26 tables of 30 rows, all of the R13 classifier profile')


def group(t, ids):
    return sum(sec for name, sec, _, _ in t['rows'] if re.match(r'slot (\d\d) ', name) and int(name[5:7]) in ids)


def mean(xs):
    return sum(xs) / len(xs)


PUB = (0, 1, 4, 14, 15, 16, 17, 18, 19)
FOLD = (5, 6, 7, 10, 11, 12, 13)
m_pub = mean([group(t, PUB) for t in T]) * 1000
m_fold = mean([group(t, FOLD) for t in T]) * 1000
m_all = mean([group(t, range(23)) for t in T]) * 1000
check(abs(m_pub - 168.9) < 0.06 and abs(m_fold - 30.4) < 0.06 and abs(m_all - 203.4) < 0.3,
      'its means a block: slots 0, 1, 4, 14 to 19 %.1f ms; the seven fold slots %.1f ms; all 23 slot rows %.1f ms '
      '(R13, default pool, pool size not stated)' % (m_pub, m_fold, m_all))
r0 = {int(name[5:7]): (sec, size, ns) for name, sec, size, ns in T[0]['rows'] if name.startswith('slot ')}
sz = {s: int(r0[s][1].split()[0]) for s in PUB}
check(sz == {0: 3145728, 1: 3145728, 4: 4194304, 14: 67108864, 15: 28311552, 16: 7077888, 17: 29360128, 18: 121634816, 19: 393216}
      and sz[14] == 2 * 64 * (1 << 19) and sz[18] == 2 * 29 * (1 << 21),
      'a verifier table prints a size for each slot row; in the first table slot 14 is 2 x 64 x 2^19 and slot 18 is '
      '2 x 29 x 2^21, twice tables times cube at R13')
worst = max(abs(float(r0[s][2]) * sz[s] / 1e9 - r0[s][0]) for s in PUB)
check(worst < 0.00051, 'the ns-a-unit column times the size gives each row\'s seconds to better than the printed '
      'millisecond (largest gap %.2f ms): sub-millisecond row times can be read that way' % (worst * 1000))
print('checks: %d, failed: %d' % (N[0], N[1]))
sys.exit(1 if N[1] else 0)
