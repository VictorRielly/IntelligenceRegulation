"""Reverify retained R-C1 bytes after recovery; no private opening is recreated."""
from datetime import datetime, timezone
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'apps/proven-media'))
from proven_media.classifier_cli import ClassifierCLI, Deployment, DEV_POLICY, R_C1_BINARY_SHA256, one_event, require


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, default=HERE / 'classifier_reverify_20261028')
    out = parser.parse_args().out
    out.mkdir(exist_ok=False)
    complete = HERE / 'classifier_integration/complete.json'
    saved = json.loads(complete.read_text())
    require(sha(HERE / 'run_classifier_integration.py') == saved['tool_sha256'], 'original integration source changed')
    fixture = HERE / 'classifier_fixture'
    require(sha(fixture / 'fixture.json') == saved['fixture_manifest_sha256'], 'original fixture changed')
    records = [(case['name'], case['record'], fixture / ('tables' if case['name'] == 'positive' else 'tables-neg'))
               for case in saved['cases']]
    records += [('multi-' + str(i), r, HERE / 'classifier_multi_tables')
                for i, r in enumerate(saved['multi_chunk']['records'])]
    results = []
    for name, record, tables in records:
        run_dir = Path(record['receipt']['run_dir'])
        require(sha(run_dir / 'statement/statement.json') == record['statement_sha256'], 'retained statement changed')
        for file in record['receipt']['files']:
            path = run_dir / file['file']
            require(path.stat().st_size == file['bytes'] and sha(path) == file['sha256'], 'retained segment changed')
        cli = ClassifierCLI(Deployment(
            binary=ROOT / 'results/zk60_token_io_r1_20261017/cli/zk60_classify.r12.release.bin',
            binary_sha256=R_C1_BINARY_SHA256, prover_export=fixture / 'prover-export',
            verifier_export=fixture / 'verifier-export', tables=tables,
            statement_identity=record['statement']['trained_statement_identity'], policy=DEV_POLICY,
            chunk_size=23, overlap=4, min_bits=93, development=True))
        holds = [ROOT / 'apps/proven-media/HOLD', ROOT / 'results/zk60_shieldstral_prep_20261021/HOLD',
                 ROOT / 'results/zk60_shieldstral_export_20261026/HOLD']
        while any(p.exists() for p in holds):
            time.sleep(15)
        log = out / (name + '.log')
        command = ['python3', str(ROOT / 'scripts/zk60_resource_guard.py'), 'run', '--class', 'light',
                   '--need-gib', '.7', '--cap-gib', '1.5', '--label', 'astra-retained-' + name,
                   '--wait-secs', '60', '--max-secs', '60', '--log', str(log),
                   '--done', str(out / (name + '.done')), '--result-json', str(out / (name + '.guard.json')),
                   '--', *cli.verify_command(run_dir)]
        rc = subprocess.run(command).returncode
        guard = json.loads((out / (name + '.guard.json')).read_text())
        require(rc == guard['exit'] == guard['child_rc'] == 0 and not guard['guard_killed'], 'guarded reverify failed')
        verified = one_event(log.read_text(), rc, 'classified')
        require(verified['trained_statement_identity'] == record['statement']['trained_statement_identity'], 'identity differs')
        verdict_bit = record['statement']['verdict_bit']
        require(verified['verdict'] == ('flagged' if verdict_bit else 'not-flagged'), 'verdict differs')
        require(verified['input_token_endpoint_root'] == record['statement']['input_token_endpoint_root'], 'input endpoint differs')
        require(sha(run_dir / 'statement/statement.json') == record['statement_sha256'], 'reverify changed statement')
        results.append({'case': name, 'verdict_bit': verdict_bit, 'guard': guard,
                        'statement_sha256': record['statement_sha256']})
    result = {'at': datetime.now(timezone.utc).isoformat(), 'source_sha256': sha(Path(__file__)),
              'original_complete_sha256': sha(complete), 'binary_sha256': R_C1_BINARY_SHA256,
              'scope': 'MEASURED four fresh-process public receipt reverifications; synthetic development profile only. Original owner checks retained, not repeated; no Shieldstral/privacy acceptance.',
              'cases': results}
    (out / 'complete.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'verified_receipts': len(results), 'verdict_bits': [r['verdict_bit'] for r in results]}))


if __name__ == '__main__':
    main()
