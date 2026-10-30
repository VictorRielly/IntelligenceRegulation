"""Publish allowlisted input-owner results for the explicitly public garden demo.

Reads terminal logs and accepted records, never token files, activations or .dec.
This is an evidence extractor; it neither launches proofs nor grants acceptance.
"""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / 'real_app_demo_1'
sys.path.insert(0, str(ROOT / 'apps/proven-media'))
from proven_media.classifier_cli import one_event, require


def main():
    plan = json.loads((OUT / 'plan.json').read_text())
    require(plan['content_tokens'] == 17, 'this capture is only for the approved public 17-id demo')
    private = Path(plan['private_root'])
    db = sqlite3.connect(f'file:{private / "app.sqlite3"}?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    rows = db.execute('SELECT j.*, c.status AS proof_status, c.record FROM jobs j '
                      'LEFT JOIN chunk_proofs c ON c.post_id=j.post_id AND c.chunk=j.chunk '
                      'WHERE j.post_id=? AND j.kind=? ORDER BY j.chunk', (plan['post_id'], 'prove')).fetchall()
    db.close()
    captures = []
    for row in rows:
        if row['status'] != 'done':
            continue
        require(row['proof_status'] == 'done' and row['record'], 'accepted queue record missing')
        record = json.loads(row['record'])
        category = record['chunk']['category']
        job = Path(row['job_dir'])
        require(job.resolve().is_relative_to(private.resolve()), 'job path outside demo private root')
        require((job / 'pipeline.done').read_text().strip() == '0', 'pipeline not successful')
        log = (job / 'logs/inowner.log').read_text()
        require((job / 'logs/inowner.exit').read_text().strip() == '0', 'input-owner did not exit cleanly')
        guard_raw = (job / 'logs/inowner.guard.json').read_bytes()
        guard = json.loads(guard_raw)
        require(all(type(guard.get(k)) is int and guard[k] == 0 for k in ('exit', 'child_rc'))
                and not any(guard.get(k) for k in ('guard_killed', 'refused', 'guard_error', 'hard_killed',
                                                   'stragglers_killed', 'gpu_drain_failed')),
                'input-owner guard did not complete cleanly')
        event = one_event(log, 0, 'content-checked')
        statement = record['statement']
        require(event['content_total'] == 17 and event['chunk'] == 0 and event['range'] == [0, 17]
                and event['verdict'] == statement['verdict'] and statement['content_length_n'] == 17
                and statement['policy'] == f'shieldstral-1.0-3b-moderate-{category}/1'
                and statement['trained_statement_identity'] ==
                '29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1'
                and record['checks']['content_binding']['ok'] is True,
                'input-owner result differs from accepted public demo record')
        captures.append({'category': category, 'policy': statement['policy'],
            'input_owner': {k: event[k] for k in ('event', 'chunk', 'range', 'content_total', 'verdict')},
            'statement_sha256': record['statement_sha256'],
            'trained_statement_identity': statement['trained_statement_identity'],
            'stdout_sha256': hashlib.sha256(log.encode()).hexdigest(),
            'guard_sha256': hashlib.sha256(guard_raw).hexdigest(),
            'guard': {k: guard[k] for k in ('exit', 'child_rc', 'child_wall_seconds', 'peak_rss_gib', 'enforcement')}})
    categories = {r['category'] for r in captures}
    require(len(categories) == len(captures) and categories <= {'sexual', 'violence', 'hate'}, 'duplicate category')
    result = {'schema': 'pm-public-demo-owner-capture/1', 'at': datetime.now(timezone.utc).isoformat(),
              'post_id': plan['post_id'], 'content_tokens': 17, 'public_input': True,
              'complete': categories == {'sexual', 'violence', 'hate'}, 'categories': captures,
              'scope': 'Retained terminal input-owner events for the authorized public garden post; '
                       'no new verification and no private opening or activation included.'}
    target = OUT / 'input_owner_capture.json'
    temporary = target.with_suffix('.tmp')
    temporary.write_text(json.dumps(result, indent=2) + '\n')
    os.replace(temporary, target)
    print(json.dumps({'complete': result['complete'], 'categories': sorted(categories), 'evidence': str(target)}))


if __name__ == '__main__':
    main()
