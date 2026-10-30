"""A5 app transport candidate; not selected by the production queue/factory.

Preparation uses the existing pinned tokenizer, complete category planner and
activation writer. Prover events route unverified receipts only. The existing
r16b fresh verify/input-owner/label commands still decide acceptance.
"""
from __future__ import annotations
import json
from dataclasses import asdict
import hashlib
import math
import os
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / 'apps/proven-media'))
from proven_media import config, proof_plans, records, shieldstral_runtime as runtime
from proven_media.classifier_cli import CONTEXT, ClassifierCLI, in_git_tree, require
from proven_media.provers import ProverError, write_private
from proven_media.shieldstral_text import ShieldstralTextEncoder, SPECIAL_TOKENS, VOCABULARY
from batch_cleanup import CleanupScope, quarantine

SCHEMA = 'zk60-classify-prove-batch/1'
ROW_KEYS = {'name', 'policy_id', 'chunk_index', 'sequence_dir', 'out', 'owner_dir'}


def validate_manifest(manifest, total):
    require(type(total) is int and 1 <= total <= 336, 'invalid whole-post count')
    require(type(manifest) is dict and set(manifest) == {'schema', 'expect_statement', 'content_total', 'jobs'},
            'invalid batch fields')
    require(manifest['schema'] == SCHEMA and manifest['expect_statement'] == runtime.IDENTITY
            and type(manifest['content_total']) is int and manifest['content_total'] == total,
            'batch model or independently counted post length changed')
    work = proof_plans.category_work_plan(total, runtime.templates())
    jobs = manifest['jobs']
    require(type(jobs) is list and len(jobs) == len(work) <= 24, 'incomplete batch')
    names, destinations = set(), []
    for row, chunk in zip(jobs, work):
        require(type(row) is dict and set(row) == ROW_KEYS, 'invalid batch job fields')
        require(type(row['name']) is str and re.fullmatch(r'[A-Za-z0-9_-]{1,48}', row['name'])
                and row['name'] not in names, 'duplicate or invalid batch job name')
        names.add(row['name'])
        require(row['policy_id'] == chunk['policy_id'] and type(row['chunk_index']) is int
                and row['chunk_index'] == chunk['category_chunk_index'], 'batch policy/chunk differs from the complete plan')
        for key in ('sequence_dir', 'out', 'owner_dir'):
            require(type(row[key]) is str and '\x00' not in row[key] and Path(row[key]).is_absolute()
                    and '..' not in Path(row[key]).parts, 'batch requires absolute paths')
        # Future sequence/output leaves may not exist yet. resolve() still
        # collapses any existing symlink parent before alias comparisons.
        out, owner = (Path(row[k]).resolve() for k in ('out', 'owner_dir'))
        destinations.extend((out, Path(str(out) + '.incomplete'), Path(str(out) + '.unverified-statement'), owner))
    for i, dst in enumerate(destinations):
        require(all(dst != old and dst not in old.parents and old not in dst.parents for old in destinations[:i]),
                'batch output/private paths overlap')
    for row in jobs:
        owner = Path(row['owner_dir']).resolve()
        require(not in_git_tree(owner), 'batch owner directory must be outside git work trees')
        for public in (Path(other['out']).resolve().parent for other in jobs):
            require(owner != public and public not in owner.parents, 'batch owner is inside a receipt parent')
    return work


def prepare_ids(post_id, ids, reserved_plan, job, receipts, *, reserved_context):
    """Internal transport boundary. The caller must supply the original post's
    pinned encoding/reservation; public prepare_text computes that encoding.
    Exclusive creation prevents a restarted worker from screening it again.
    """
    require(config.prover_mode() == 'shieldstral' and reserved_context == records.screening_context(),
            'original screening context differs from the real classifier configuration')
    require(type(post_id) is str and re.fullmatch(r'[A-Za-z0-9_-]{1,80}', post_id), 'invalid post id')
    require(type(ids) is tuple and 1 <= len(ids) <= 336
            and all(type(i) is int and SPECIAL_TOKENS <= i < VOCABULARY for i in ids), 'invalid content encoding')
    work = proof_plans.category_work_plan(len(ids), runtime.templates())
    proof_plans.check_plan(reserved_plan, work)
    require(not Path(job).is_symlink(), 'private job path is a symlink')
    job, receipts = Path(job).resolve(), Path(receipts).resolve()
    require(job.parent.is_dir() and receipts.is_dir() and not in_git_tree(job), 'invalid private/receipt roots')
    require(not job.exists() and not job.is_symlink(), 'batch is already prepared; no automatic retry')
    content = job / 'content.ids'
    jobs = []
    for chunk in work:
        name = f'c{chunk["index"]}'
        jobs.append({'name': name, 'policy_id': chunk['policy_id'], 'chunk_index': chunk['category_chunk_index'],
                     'sequence_dir': str(job / 'activations' / name),
                     'out': str(receipts / f'{post_id}-{name}'), 'owner_dir': str(job / 'owners' / name)})
    manifest = {'schema': SCHEMA, 'expect_statement': runtime.IDENTITY, 'content_total': len(ids), 'jobs': jobs}
    validate_manifest(manifest, len(ids))
    for row in jobs:
        for suffix in ('', '.incomplete', '.unverified-statement'):
            path = Path(row['out'] + suffix)
            require(not path.exists() and not path.is_symlink(), 'a batch receipt path already exists')
    job.mkdir(mode=0o700, exist_ok=False)
    (job / 'owners').mkdir(mode=0o700)
    write_private(content, (','.join(map(str, ids)) + '\n').encode())
    request = [{'name': r['name'], 'policy_id': r['policy_id'], 'content_file': str(content),
                'chunk_index': r['chunk_index']} for r in jobs]
    write_private(job / 'activation-request.json', records.canonical(request))
    write_private(job / 'batch-request.json', records.canonical(manifest))
    write_private(job / 'prepared.json', records.canonical({'schema': 'pm-classifier-batch-candidate/1',
        'post_id': post_id, 'reserved_plan': reserved_plan, 'screening_context': records.screening_context(),
        'status': 'prepared; unverified; not integrated with the app queue'}))
    scope = cleanup_scope(manifest, len(ids), post_id, job, receipts)
    write_private(job / 'cleanup-scope.json', records.canonical(asdict(scope)))
    return manifest


def prepare_text(post_id, text, reserved_plan, job, receipts, *, reserved_context):
    ids = ShieldstralTextEncoder(runtime.TEKKEN).content_ids(text)
    return prepare_ids(post_id, ids, reserved_plan, job, receipts, reserved_context=reserved_context)


def prove_command(manifest, total, job, candidate_binary, candidate_sha256):
    """Command construction only. Execution must use the shared resource guard.
    A candidate binary is explicit and is never installed as the app default.
    """
    validate_manifest(manifest, total)
    job, binary = Path(job).resolve(), Path(candidate_binary).resolve()
    require(binary != runtime.BINARY.resolve() and candidate_sha256 != runtime.BINARY_SHA,
            'r16b has no prove-batch command')
    require(re.fullmatch(r'[0-9a-f]{64}', candidate_sha256) is not None
            and records.sha256_file(binary) == candidate_sha256, 'batch binary differs from candidate pin')
    require(records.canonical(json.loads((job / 'batch-request.json').read_bytes())) == records.canonical(manifest),
            'batch request changed after preparation')
    return [str(binary), 'prove-batch', '--export', str(runtime.EXPORT), '--tables', str(runtime.VERIFIER_EXPORT / 'token_io'),
            '--content-file', str(job / 'content.ids'), '--batch-file', str(job / 'batch-request.json'), '--label', CONTEXT]


def fresh_check_commands(manifest, total, job):
    """Use the reviewed verifier in new processes; no batch prover verdict is
    accepted here. collect_verified/collect_label must validate their results.
    """
    work = validate_manifest(manifest, total)
    clis = {t.policy_id: ClassifierCLI(runtime.deployment(t)) for t in runtime.templates()}
    commands = []
    grouped = {t.policy_id: [] for t in runtime.templates()}
    for row, chunk in zip(manifest['jobs'], work):
        cli = clis[row['policy_id']]
        commands.append((row['name'] + '-verify', cli.verify_command(row['out'])))
        commands.append((row['name'] + '-inowner', cli.owner_command(row['out'], Path(row['owner_dir']) / 'input.dec', Path(job) / 'content.ids')))
        grouped[row['policy_id']].append(row['out'])
    for policy, paths in grouped.items():
        commands.append((policy.split('-moderate-')[1].split('/')[0] + '-label', clis[policy].label_command(paths, total)))
    return commands


def _nonnegative(value):
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def _unique_object(pairs):
    obj = {}
    for key, value in pairs:
        if key in obj:
            raise ValueError('duplicate JSON key')
        obj[key] = value
    return obj


def cleanup_scope(manifest, total, post_id, job, receipts):
    """Fix the authorized output locations before starting a batch child."""
    validate_manifest(manifest, total)
    job, receipts = Path(job).resolve(), Path(receipts).resolve()
    for i, row in enumerate(manifest['jobs']):
        require(row['name'] == f'c{i}' and row['out'] == str(receipts / f'{post_id}-c{i}')
                and row['owner_dir'] == str(job / 'owners' / f'c{i}')
                and row['sequence_dir'] == str(job / 'activations' / f'c{i}'),
                'batch paths differ from the prepared app scope')
    return CleanupScope(post_id, str(job), str(receipts), len(manifest['jobs']),
                        hashlib.sha256(records.canonical(manifest)).hexdigest())


def collect_batch_result(stdout, rc, manifest, total, guard_record, scope, *, terminal_confirmed):
    """The queue's terminal boundary, including recovery after failure/kill.

    A caller retains the prepared scope (cleanup-scope.json), and checks its
    job/post/receipt roots against its own queue configuration on restart.
    Guard completion alone never accepts a proof; normal native fresh checks
    follow only the unverified result returned here.
    """
    require(terminal_confirmed is True and isinstance(scope, CleanupScope), 'batch child is not confirmed terminal')
    try:
        require(hashlib.sha256(records.canonical(manifest)).hexdigest() == scope.manifest_sha256,
                'batch request changed after launch')
        g = guard_record
        require(type(g) is dict and type(g.get('exit')) is int and g['exit'] == 0
                and type(g.get('child_rc')) is int and g['child_rc'] == 0
                and not any(g.get(k) for k in ('guard_killed', 'refused', 'guard_error', 'hard_killed',
                                             'stragglers_killed', 'gpu_drain_failed')),
                'batch guard did not report clean child completion')
        return split_unverified_log(stdout, rc, manifest, total)
    except Exception:
        try:
            quarantine(scope, terminal_confirmed=True)
        except Exception as exc:
            raise ProverError('Batch failed; quarantine needs recovery. Publication and retries remain blocked.') from exc
        raise ProverError('Batch failed; outputs quarantined. No proof is accepted and no automatic retry is allowed.') from None


def split_unverified_log(stdout, rc, manifest, total):
    """Validate a complete, ordered event stream and route private per-run logs.
    Success means transport completed, NOT proof acceptance. On any malformed,
    failed or partial stream no per-run success result is returned.
    """
    work = validate_manifest(manifest, total)
    require(type(rc) is int and rc == 0, 'batch prover did not exit successfully')
    require(type(stdout) is str and len(stdout.encode()) <= 2 << 20, 'batch log is too large')
    jobs, logs = manifest['jobs'], {}
    current, events, next_index, loaded, terminal = None, [], 0, False, False
    for line in stdout.splitlines():
        if not line.strip():
            continue
        try:
            e = json.loads(line, object_pairs_hook=_unique_object,
                           parse_constant=lambda _: (_ for _ in ()).throw(ValueError('nonfinite JSON')))
        except (ValueError, TypeError):
            require(False, 'malformed batch event')
        require(type(e) is dict and not terminal, 'unexpected event after batch completion')
        kind = e.get('event')
        if kind == 'batch-loaded':
            require(not loaded and next_index == 0 and current is None and type(e.get('jobs')) is int
                    and e['jobs'] == len(jobs) and type(e.get('model_loads')) is int and e['model_loads'] == 1
                    and type(e.get('table_loads')) is int and e['table_loads'] == 1
                    and e.get('trained_statement_identity') == runtime.IDENTITY and e.get('context_label') == CONTEXT
                    and _nonnegative(e.get('load_seconds')), 'invalid shared model-load event')
            loaded = True
        elif kind == 'batch-job-start':
            require(loaded and current is None and next_index < len(jobs), 'unexpected job start')
            row = jobs[next_index]
            require(type(e.get('index')) is int and e['index'] == next_index and e.get('name') == row['name']
                    and e.get('policy') == row['policy_id'] and type(e.get('chunk')) is int
                    and e['chunk'] == row['chunk_index'], 'batch job identity changed')
            current, events = next_index, []
        elif kind in ('loaded', 'segment', 'proved'):
            require(current is not None, 'native event outside a batch job')
            events.append(e)
        elif kind == 'batch-job-proved':
            require(current is not None and type(e.get('index')) is int and e['index'] == current
                    and e.get('name') == jobs[current]['name'], 'wrong job completion')
            row, chunk = jobs[current], work[current]
            require(len(events) == 30 and [x['event'] for x in events] == ['loaded'] + ['segment'] * 28 + ['proved'],
                    'missing, duplicated or reordered native proof events')
            a, z = events[0], events[-1]
            for k, value in {'policy': row['policy_id'], 'chunk': row['chunk_index'], 'chunks': chunk['category_chunks']}.items():
                require(records.canonical(a.get(k)) == records.canonical(value)
                        and records.canonical(z.get(k)) == records.canonical(value), 'native event differs from job')
            require(a.get('trained_statement_identity') == runtime.IDENTITY and a.get('run_profile') == runtime.RUN_PROFILE
                    and type(a.get('blocks')) is int and a['blocks'] == 26
                    and type(a.get('content_length_n')) is int and a['content_length_n'] == chunk['end'] - chunk['start'],
                    'native loaded event differs from whole-post plan')
            sizes = []
            for i, part in enumerate(events[1:-1]):
                require(type(part.get('index')) is int and part['index'] == i
                        and type(part.get('bytes')) is int and part['bytes'] > 0 and _nonnegative(part.get('elapsed_seconds')),
                        'invalid native segment event')
                sizes.append(part['bytes'])
            require(z.get('run') == row['out'] and z.get('owner_dir') == row['owner_dir']
                    and type(z.get('segments')) is int and z['segments'] == 28
                    and type(z.get('receipt_bytes')) is int and z['receipt_bytes'] == sum(sizes)
                    and type(z.get('whole_run_floor_bits')) is int and z['whole_run_floor_bits'] >= 95
                    and z.get('verdict') in ('flagged', 'not-flagged')
                    and _nonnegative(z.get('prove_seconds')) and _nonnegative(z.get('total_seconds')),
                    'invalid native proof summary')
            logs[row['name']] = '\n'.join(json.dumps(x, sort_keys=True) for x in events) + '\n'
            next_index += 1
            current, events = None, []
        elif kind == 'batch-proved':
            require(loaded and current is None and next_index == len(jobs)
                    and type(e.get('jobs')) is int and e['jobs'] == len(jobs) and e.get('verified') is False
                    and _nonnegative(e.get('total_seconds')), 'partial or invalid batch completion')
            terminal = True
        else:
            require(False, 'batch reported refusal or an unknown event')
    require(terminal and len(logs) == len(jobs), 'batch completion missing')
    return {'status': 'unverified', 'logs': logs}
