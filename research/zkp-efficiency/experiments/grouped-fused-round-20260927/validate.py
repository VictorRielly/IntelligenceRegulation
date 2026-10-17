#!/usr/bin/env python3
"""CPU-light artifact and provenance validation; does not run a proof."""
import hashlib
import json
import os
from pathlib import Path
import resource
import signal

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def sha(b):
    return hashlib.sha256(b).hexdigest()


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(10)
    manifest = json.loads((HERE/'artifact-hashes.json').read_text())
    for name, digest in manifest.items():
        assert sha((HERE/name).read_bytes()) == digest, name
    pins = json.loads((HERE/'source-pins.json').read_text())
    for pin in pins:
        assert sha((HERE/pin['snapshot']).read_bytes()) == pin['sha256'], pin
        assert sha(Path(pin['source']).read_bytes()) == pin['sha256'], pin
    history = json.loads((HERE/'history-before.json').read_text())
    for name in ('FINDINGS.md', 'sources.jsonl'):
        old = history[name]
        assert sha((ROOT/name).read_bytes()[:old['bytes']]) == old['sha256'], name
    assert sha((ROOT/'AGENDA.md').read_bytes()) == history['AGENDA.md']['sha256']
    assert sha((HERE/'STATE.before.md').read_bytes()) == history['STATE.md']['sha256']
    sources = [json.loads(s) for s in (ROOT/'sources.jsonl').read_text().splitlines()]
    assert len({s['id'] for s in sources}) == len(sources)
    new_sources = json.loads((HERE/'source-records.json').read_text())
    assert sources[-len(new_sources):] == new_sources
    r = json.loads((HERE/'result.json').read_text())
    assert r['source_sha256'] == sha((HERE/'experiment.py').read_bytes())
    initial = json.loads((HERE/'initial/result.json').read_text())
    assert initial['source_sha256'] == sha((HERE/'initial/experiment.py').read_bytes())
    assert r['status'] == initial['status'] == 'passed'
    assert r['direct_round_points'] == r['samples'] == 651
    assert r['independent_final_mles'] == 962 and r['group_samples'] == 1953
    assert r['differential_cases'] == len(r['cases']) == 37
    assert r['zero_factor_fallbacks'] == 6
    assert len(r['negative_controls']) == 10 and all(r['negative_controls'].values())
    assert r['schedule_refusals'] == 12 and r['malformed_refusals'] == 3
    for c in r['cases']:
        n, k = c['rows'], c['tables']
        assert c['extra_partial_additions'] == 0
        assert c['reads_unfused']-c['reads_fused'] == max(0, n-2)*k
        assert c['logical_bytes_unfused'] == 16*(c['reads_unfused']+c['writes'])
        assert c['logical_bytes_fused'] == 16*(c['reads_fused']+c['writes'])
        if n == 256:
            assert c['brackets'] == ([1148,638,638] if c['padded'] else [893,383,383])
    assert r['elapsed_s'] < 60 and r['peak_rss_kib'] < 512*1024
    assert all(r[k] is None for k in ('proving_s','verification_s','complete_readiness_s'))
    assert not r['native_compiled'] and not r['gpu_executed']
    b = json.loads((HERE/'bottleneck.json').read_text())
    assert sha(Path(b['comparison_path']).read_bytes()) == b['comparison_sha256']
    for x in b['runs']:
        assert sha(Path(x['log_path']).read_bytes()) == x['sha256']
    assert Path(b['terminal_marker']['path']).read_text().strip() == '0'
    assert (HERE/'run.done').read_text().strip() == '0'
    result = dict(status='passed', artifact_hashes=len(manifest), source_and_snapshot_pairs=len(pins),
                  original_history_prefixes=2, previous_state_preserved=True, agenda_unchanged=True,
                  owner_logs_rechecked=len(b['runs']), appended_source_records=len(new_sources),
                  arithmetic_accounting=True, result_source_bindings=True,
                  scope='Artifact/provenance check; no native proof or code-sketch compilation')
    (HERE/'validation.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
