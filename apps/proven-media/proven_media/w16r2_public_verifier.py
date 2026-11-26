"""Verify a W16R2 publication using public artifacts and the reviewed native verifier."""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile
import time

from . import config, proof_plans, records, shieldstral_fast_runtime as baseline, w16r2_runtime as w16
from .w16r2_export import KIT_BINARY
from .classifier_cli import R_C3_SCHEMA, require
from .provers import ProverError

GUARD_SHA = 'ed8b5b38660c88f723be8c0293f48b6a38f54099d143f37ea2fcf9be4b410f17'
# One standalone native checker runs under the shared GPU guard. The publisher
# separately admits its resident writers, provers and checkers as one service.
NEED_GIB, CAP_GIB, MAX_SECONDS = 12, 16, 900
MAX_METADATA = 1 << 20
MAX_LOG = 16 << 20
MAX_SEGMENT = 256 << 20
MAX_RECEIPT = 4 << 30
NAMES = tuple(f'segment-{i:03}.bin' for i in range(28))


def _digest(value):
    require(type(value) is str and re.fullmatch(r'[0-9a-f]{64}', value) is not None, 'invalid public digest')
    return value


def signed_post_coverage(manifest):
    """Reconstruct the claimed whole-post decisions from the registered public plan."""
    item, entries, labels = manifest.get('item'), manifest.get('entries'), manifest.get('labels')
    require(isinstance(item, dict) and item.get('kind') == 'text', 'W16R2 needs a text item')
    require(isinstance(entries, list) and isinstance(labels, dict), 'missing W16R2 entries or labels')
    if (all(label == {'value':records.UNPROVED, 'proof':'none'} for label in labels.values())
            and all(entry.get('verdict') == records.UNPROVED and entry.get('proof_status') == 'none'
                    and entry.get('verdict_bound_by_proof') is False
                    and all(entry.get(k) is None for k in ('statement_sha256','anchor','bundle')) for entry in entries)):
        # An owner may retain a signed failure report even when planning yielded no jobs.
        return None
    total = item.get('content_length_tokens')
    commitment = _digest(item.get('content_commitment'))
    templates = baseline.templates()
    plan = proof_plans.category_work_plan(total, templates)
    require(len(entries) == len(plan), 'signed entries do not cover every planned category and chunk')
    policies = {c['id']:c for c in baseline.categories()}
    intake = w16.authority()
    digest = hashlib.sha256(records.canonical([[k,c['sha256']] for k,c in policies.items()])).hexdigest()
    require(manifest.get('category_set') == {'id':config.W16R2_CATEGORY_SET_ID, 'digest':digest},
            'signed category set differs from the registered W16R2 policies')

    values = {t.category:[] for t in templates}
    seen = set()
    statements = set()
    threshold = records.threshold()
    for entry in entries:
        index = entry.get('chunk')
        require(type(index) is int and 0 <= index < len(plan) and index not in seen,
                'duplicate or unexpected signed chunk')
        seen.add(index)
        chunk = plan[index]
        category = chunk['category']
        expected = {'category':category, 'category_chunk_index':chunk['category_chunk_index'],
                    'token_range':[chunk['start'],chunk['end']], 'policy_id':chunk['policy_id'],
                    'policy_sha256':policies[category]['sha256'], 'content_commitment':commitment,
                    'threshold':{k:threshold[k] for k in ('tau','c')}}
        require(all(records.canonical(entry.get(k)) == records.canonical(v) for k,v in expected.items()),
                'signed chunk range, category, policy, threshold or post commitment differs')
        verdict = entry.get('verdict')
        require(verdict in ('yes','no',records.UNPROVED), 'unknown signed W16R2 verdict')
        proved = verdict != records.UNPROVED
        require(entry.get('proof_status') == ('accepted' if proved else 'none')
                and entry.get('verdict_bound_by_proof') is proved, 'signed verdict and proof status disagree')
        if proved:
            statement = _digest(entry.get('statement_sha256'))
            require(isinstance(entry.get('anchor'), dict) and isinstance(entry.get('bundle'), dict),
                    'proved W16R2 entry needs a publication anchor and receipt inventory')
            require(statement not in statements, 'duplicate W16R2 statement')
            require(entry.get('profile_id') == w16.PROFILE_SHA and entry.get('verifier_id') == intake['binary_sha256']
                    and entry.get('model_id') == intake['statement_identity'], 'signed W16R2 proof identity differs')
            statements.add(statement)
        else:
            require(all(entry.get(k) is None for k in ('statement_sha256','anchor','bundle')),
                    'unproved chunk names proof evidence')
        values[category].append(verdict)

    geometry = {t.category:{'chunks':len(values[t.category]), 'chunk_tokens':t.chunk_size,
                            'overlap_tokens':t.overlap} for t in templates}
    expected_geometry = {'profile':'per-category', 'n_chunks':len(plan), 'categories':geometry}
    require(records.canonical(manifest.get('chunking')) == records.canonical(expected_geometry),
            'signed chunking summary differs from the registered plan')
    expected_labels = {category:records.aggregate_verdicts(bits) for category,bits in values.items()}
    require(labels == expected_labels, 'whole-post labels differ from the signed chunk verdicts')
    return {'content_tokens':total, 'planned_chunks':len(plan), 'accepted_chunks':len(statements),
            'labels':expected_labels}


def _object_pairs(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate JSON key')
        result[key] = value
    return result


def _json(raw):
    def refuse_constant(value):
        raise ProverError('non-finite JSON constant')
    return json.loads(raw, object_pairs_hook=_object_pairs, parse_constant=refuse_constant)


def _read(path, maximum):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        st = os.fstat(stream.fileno())
        require(stat.S_ISREG(st.st_mode) and st.st_size <= maximum, 'public metadata extent or file type differs')
        raw = stream.read(maximum + 1)
    require(len(raw) <= maximum, 'public metadata exceeds bound')
    return raw


def _context(pub, manifest, post_id):
    require(type(manifest) is dict, 'publication manifest must be an object')
    require(type(post_id) is str and re.fullmatch(r'[A-Za-z0-9_-]{1,80}', post_id) is not None,
            'invalid publication post id')
    intake = w16.authority()
    category = next((c for c in baseline.categories() if c['id'] == manifest.get('category')), None)
    require(category is not None and manifest.get('post_id') == post_id, 'publication category or post differs')
    expected = {'model_id': intake['statement_identity'], 'verifier_id': intake['binary_sha256'],
                'profile_id': w16.PROFILE_SHA, 'policy_id': category['sha256']}
    require(all(manifest.get(k) == v for k, v in expected.items())
            and manifest.get('verdict') in ('yes', 'no'), 'W16R2 publication differs from reviewed native pins')
    require(type(manifest.get('chunk')) is int and manifest['chunk'] >= 0, 'invalid publication chunk')
    bounds = manifest.get('token_range')
    require(type(bounds) is list and len(bounds) == 2 and all(type(n) is int for n in bounds)
            and 0 <= bounds[0] < bounds[1], 'invalid publication token range')
    kit_path = os.environ.get('PM_W16R2_VERIFIER_KIT')
    if kit_path:
        kit = Path(kit_path).resolve(strict=True)
        binary, export = kit / KIT_BINARY, kit / 'export'
        environment = baseline.native_environment(models=kit / 'models')
    else:
        binary = w16.BINARY
        export = Path(pub.store).parent / 'verifier-export-w16r2-94643880'
        environment = baseline.native_environment()
    require(binary.is_file() and not binary.is_symlink() and records.sha256_file(binary) == intake['binary_sha256'],
            'W16R2 verifier binary differs')
    require(export.is_dir() and not export.is_symlink() and (export / 'token_io').is_dir()
            and not (export / 'token_io').is_symlink()
            and not any(p.name.startswith('seq_') for p in export.iterdir()), 'public verifier export is unavailable or includes sequences')
    raw = _read(export / 'profile.json', MAX_METADATA)
    require(hashlib.sha256(raw).hexdigest() == w16.PROFILE_SHA, 'public verifier profile differs')
    hardware_raw = _read(config.DEPLOY_FILE, MAX_METADATA)
    settings = _json(hardware_raw)
    require(type(settings) is dict and type(settings.get('classifier_profiles')) is dict,
            'malformed hardware authority')
    hardware = settings['classifier_profiles'].get('shieldstral-mac-fast-w16r2', {})
    require(type(hardware) is dict, 'malformed W16R2 hardware authority')
    expected_hardware = {'prover_mode': w16.KIND, 'binary_sha256': intake['binary_sha256'],
        'statement_identity': intake['statement_identity'], 'profile_sha256': w16.PROFILE_SHA,
        'native_intake_sha256': w16.INTAKE_SHA, 'native_cli_flags': [w16.FLAG],
        'public_content_only': True, 'production': False, 'min_bits': 95,
        'native_settings': dict(w16.NATIVE_SETTINGS),
        'guard_resources': {'service': {'need_gib': 196, 'cap_gib': 220, 'max_seconds': 21600}}}
    require(all(records.canonical(hardware.get(k)) == records.canonical(v) for k, v in expected_hardware.items()),
            'W16R2 public verification hardware authority differs')
    require(records.sha256_file(config.GUARD) == GUARD_SHA, 'resource guard source differs')
    environment = {**environment, **w16.NATIVE_SETTINGS,
        'RAYON_NUM_THREADS': '4', 'OPENBLAS_NUM_THREADS': '4', 'OMP_NUM_THREADS': '4',
        'VECLIB_MAXIMUM_THREADS': '4', 'HL_A26_VERIFY_ONCE': '0', 'HL_A28_SEAL_AHEAD': '0'}
    return {'intake': intake, 'intake_sha256': w16.INTAKE_SHA, 'binary': binary, 'export': export, 'category': category,
            'hardware_sha256': hashlib.sha256(hardware_raw).hexdigest(), 'environment': w16.verifier_environment(environment)}


def _statement(raw, manifest, context):
    value = _json(raw)
    intake, category = context['intake'], context['category']
    require(type(value) is dict, 'statement must be an object')
    expected = {'schema': R_C3_SCHEMA, 'run_profile': intake['run_profile'],
                'trained_statement_identity': intake['statement_identity'], 'policy': category['policy_id'],
                'context_label': 'zk60-classify-verdict', 'blocks': 26, 'T': 128,
                'verdict_bit': 1 if manifest['verdict'] == 'yes' else 0}
    require(all(records.canonical(value.get(k)) == records.canonical(v) for k, v in expected.items()),
            'public statement differs from W16R2 publication')
    floor = value.get('whole_run_floor_bits')
    require(type(floor) in (int, float) and math.isfinite(floor) and floor >= 95, 'statement floor is insufficient')
    _digest(value.get('input_token_endpoint_root'))
    chunk = value.get('chunk')
    require(type(chunk) is dict and type(chunk.get('content_total')) is int and chunk['content_total'] > 0,
            'statement lacks a complete content length')
    templates = baseline.templates()
    maximum = min(t.chunk_size + (t.max_chunks - 1) * (t.chunk_size - t.overlap) for t in templates)
    require(chunk['content_total'] <= maximum, 'statement content length exceeds registered profile')
    plan = proof_plans.category_work_plan(chunk['content_total'], templates)
    require(manifest['chunk'] < len(plan), 'publication chunk is outside the complete plan')
    selected = plan[manifest['chunk']]
    require(selected['category'] == category['id'] and manifest['token_range'] == [selected['start'], selected['end']],
            'publication category or range differs from the complete plan')
    template = next(t for t in templates if t.category == category['id'])
    expected_chunk = {'index': selected['category_chunk_index'], 'count': selected['category_chunks'],
                      'range': manifest['token_range'], 'chunk_size': template.chunk_size, 'overlap': template.overlap}
    require(all(records.canonical(chunk.get(k)) == records.canonical(v) for k, v in expected_chunk.items()),
            'statement category-local chunk differs')
    require(value.get('template_prefix_ids') == list(template.prefix)
            and value.get('template_suffix_ids') == list(template.suffix), 'statement template differs')
    return value


def _inventory(manifest):
    rows = manifest.get('segments')
    require(type(rows) is list and len(rows) == len(NAMES) and all(type(r) is dict for r in rows),
            'W16R2 receipt needs all 28 segments')
    require(all(type(r.get('file')) is str for r in rows)
            and sorted(r['file'] for r in rows) == list(NAMES), 'receipt filenames differ')
    require(manifest.get('segments_json_sha256') is None, 'unexpected native segment manifest for R-C3')
    total = 0
    for row in rows:
        _digest(row.get('sha256'))
        size = row.get('bytes')
        require(type(size) is int and 0 < size <= MAX_SEGMENT, 'segment extent exceeds limit')
        total += size
    require(total <= MAX_RECEIPT, 'receipt extent exceeds limit')
    return rows


def _copy_segment(source, target, row):
    fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW)
    digest, size = hashlib.sha256(), 0
    with os.fdopen(fd, 'rb') as stream:
        st = os.fstat(stream.fileno())
        require(stat.S_ISREG(st.st_mode) and st.st_size == row['bytes'], 'CAS segment file type or extent differs')
        with target.open('xb') as out:
            for data in iter(lambda: stream.read(1 << 20), b''):
                size += len(data)
                require(size <= row['bytes'], 'CAS segment grew during copying')
                out.write(data)
                digest.update(data)
    require(size == row['bytes'] and digest.hexdigest() == row['sha256'], 'CAS segment digest differs')
    target.chmod(0o400)


def _wait_for_admission():
    deadline = time.monotonic() + min(config.GUARD_WAIT_SECS, 3600)
    while True:
        require(not config.HOLD_FILE.exists(), 'app lane is held; no verifier launched')
        result = subprocess.run(['python3', str(config.GUARD), 'check', '--class', 'gpu',
                                 '--need-gib', str(NEED_GIB)], capture_output=True, text=True, timeout=30)
        if result.returncode == 0 and 'OK to start now' in result.stdout.splitlines():
            return
        require(result.returncode == 1 and 'WOULD WAIT/REFUSE:' in result.stdout,
                'resource admission check failed')
        require(time.monotonic() < deadline, 'resource admission wait expired; no verifier launched')
        time.sleep(5)


def _guarded_command(base, run, context, post_id):
    intake, export, category = context['intake'], context['export'], context['category']
    return ['python3', str(config.GUARD), 'run', '--class', 'gpu', '--need-gib', str(NEED_GIB),
        '--cap-gib', str(CAP_GIB), '--max-secs', str(MAX_SECONDS), '--wait-secs', '3600',
        '--label', 'pm-w16r2-verifypub-' + post_id[:12], '--log', str(base / 'verify.log'),
        '--done', str(base / 'verify.done'), '--result-json', str(base / 'verify.guard.json'), '--',
        str(context['binary']), 'verify', '--export', str(export), '--tables', str(export / 'token_io'),
        '--policy', category['policy_id'], '--label', 'zk60-classify-verdict', '--artifact', str(run),
        '--expect-statement', intake['statement_identity'], '--min-bits', '95', w16.FLAG]


def _outcome(base, rc, statement, manifest, context):
    terminal = _json(_read(base / 'verify.guard.json', MAX_METADATA))
    require(_read(base / 'verify.done', 32).strip() == b'0' and rc == 0, 'guarded verifier did not exit successfully')
    require(type(terminal) is dict and all(type(terminal.get(k)) is int and terminal[k] == 0
            for k in ('exit', 'child_rc', 'stragglers_killed', 'hard_killed'))
            and 'guard_killed' in terminal and 'guard_error' in terminal
            and terminal['guard_killed'] is None and terminal['guard_error'] is None,
            'guarded verification did not terminate cleanly')
    events = [_json(line) for line in _read(base / 'verify.log', MAX_LOG).decode().splitlines()
              if line.lstrip().startswith('{')]
    require(all(type(e) is dict for e in events), 'invalid verifier event')
    successes = [e for e in events if e.get('event') == 'classified']
    require(len(successes) == 1 and not any(e.get('event') in ('refused', 'app-outcome') for e in events),
            'missing, conflicting or refused native verification outcome')
    event = successes[0]
    expected = {'trained_statement_identity': context['intake']['statement_identity'],
                'policy': context['category']['policy_id'],
                'verdict': 'flagged' if manifest['verdict'] == 'yes' else 'not-flagged',
                'chunk': statement['chunk']['index'], 'chunks': statement['chunk']['count'],
                'input_token_endpoint_root': statement['input_token_endpoint_root']}
    require(all(records.canonical(event.get(k)) == records.canonical(v) for k, v in expected.items()),
            'native verifier outcome differs from publication')
    floor = event.get('whole_run_floor_bits')
    require(type(floor) in (int, float) and math.isfinite(floor) and floor >= 95, 'native verification floor is insufficient')
    return event, terminal


def run_verifier(pub, manifest, post_id):
    """Return a refusal on unsupported/pending authority; never infer proof acceptance."""
    base = None
    result = {'ok': False, 'public_content_only': True, 'production': False,
              'fresh_input_owner_check': False, 'reconstructed_receipts_retained': False}
    try:
        context = _context(pub, manifest, post_id)
        rows = _inventory(manifest)
        raw = _read(pub._obj(_digest(manifest.get('statement_sha256'))), MAX_METADATA)
        require(hashlib.sha256(raw).hexdigest() == manifest['statement_sha256'], 'CAS statement digest differs')
        statement = _statement(raw, manifest, context)
        parent = Path(pub.store).parent / 'verify-from-store'
        parent.mkdir(parents=True, exist_ok=True)
        require(not parent.is_symlink(), 'verification evidence directory is a symlink')
        base = Path(tempfile.mkdtemp(prefix='w16r2-' + post_id[:16] + '-', dir=parent))
        (base / 'publication.json').write_bytes(records.canonical(manifest))
        with tempfile.TemporaryDirectory(prefix='receipt-', dir=base) as temporary:
            run = Path(temporary) / 'run'
            (run / 'statement').mkdir(parents=True)
            (run / 'statement/statement.json').write_bytes(raw)
            for row in rows:
                _copy_segment(pub._obj(row['sha256']), run / row['file'], row)
            _wait_for_admission()
            require(_context(pub, manifest, post_id) == context, 'public verifier authority changed while waiting')
            require(not config.HOLD_FILE.exists(), 'app lane is held; no verifier launched')
            command = _guarded_command(base, run, context, post_id)
            env = w16.verifier_environment(dict(os.environ, **context['environment']))
            env.pop('HL_OWNER_PRIVATE_DIR', None)
            rc = subprocess.run(command, capture_output=True, text=True, env=env).returncode
            event, terminal = _outcome(base, rc, statement, manifest, context)
            require(_context(pub, manifest, post_id) == context, 'public verifier authority changed during verification')
            require(_read(run / 'statement/statement.json', MAX_METADATA) == raw, 'verified statement changed')
            for row in rows:
                path = run / row['file']
                require(not path.is_symlink() and path.stat().st_size == row['bytes']
                        and records.sha256_file(path) == row['sha256'], 'verified receipt snapshot changed')
            result.update(ok=True, exit=rc, verified=event, guard=terminal,
                          content_tokens=statement['chunk']['content_total'],
                          native_intake_sha256=context['intake_sha256'], statement_sha256=manifest['statement_sha256'])
    except (ProverError, OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        result['why'] = str(error)
    if base is not None:
        result['evidence_dir'] = str(base)
        try:
            (base / 'verification.json').write_bytes(records.canonical(result))
        except OSError:
            result.update(ok=False, why='verification evidence could not be saved')
    return result
