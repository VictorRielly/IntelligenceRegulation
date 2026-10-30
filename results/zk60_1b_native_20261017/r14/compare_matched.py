"""Compare only hash-matched native public synthetic R13/R14 cases."""
from datetime import datetime, timezone
import hashlib, json
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
rows = []
for mode in ['non-dd', 'dd']:
    a_path = HERE / 'matched-r13' / ('sol-r13-matched-' + mode + '-2.result.json')
    b_path = HERE / ('sol-r14-matched-' + mode + '-1.result.json')
    a = json.loads(a_path.read_text())
    b_all = json.loads(b_path.read_text())
    b = b_all['measurement']
    ga = json.loads((a_path.parent / ('sol-r13-matched-' + mode + '-2.guard.json')).read_text())
    gb = b_all['guard']
    for key in ['tokens', 'blocks', 'dd', 'model_identity', 'block_digest', 'fixture_helpers_sha256']:
        assert a[key] == b[key], key
    row = {'mode': mode, 'same_model_identity': a['model_identity'], 'same_block_digest': a['block_digest'],
        'same_fixture_helpers_sha256': a['fixture_helpers_sha256'],
        'r13': {'prove_seconds': a['prove_seconds'], 'verify_seconds': a['verify_seconds'],
            'guard_sampled_peak_rss_gib': ga['peak_rss_gib'], 'process_hwm_mib': a['process_hwm_mib'],
            'segment_bytes': a['bytes'], 'total_segment_bytes': sum(a['bytes'])},
        'r14': {'prove_seconds': b['prove_seconds'], 'verify_seconds': b['verify_seconds'],
            'guard_sampled_peak_rss_gib': gb['peak_rss_gib'], 'prove_process_hwm_mib': b['prove_hwm_mib'],
            'segment_bytes': b['bytes'], 'total_segment_bytes': sum(b['bytes'])},
        'prove_time_reduction_percent': 100 * (1 - b['prove_seconds'] / a['prove_seconds']),
        'sampled_peak_reduction_percent': 100 * (1 - gb['peak_rss_gib'] / ga['peak_rss_gib']),
        'receipt_increase_percent': 100 * (sum(b['bytes']) / sum(a['bytes']) - 1),
        'evidence_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [a_path, b_path]},
    }
    rows.append(row)
report = {'utc': datetime.now(timezone.utc).isoformat(), 'rows': rows,
    'scope': 'MEASURED n=1 per variant on shared host, native T128 two-block public sparse synthetic fixture; exact same helper functions, input, public matrices/gains, model identity and two layer calibrations. No approved trained model or 26-block throughput claim.',
    'timers': 'Around prove_run / split_run::prove only; excludes initial fixture/witness/endpoint preparation and later verification/controls, includes on-demand second witness. Verify timer measures first full verification only.',
    'memory': 'Guard RSS sampled at0.5s across process tree, may miss spikes; process HWM also retained. Watchdog-only sandbox, no kernel cap. Shared heavy lock held and guard status checked; not a quiesced production benchmark.',
    'sources': {'r13_base': 'bb9eb2123c9350c738dafd19fe3b0133d6e2e7ab93f1e765cac4f20ccaed69ec',
        'r13_test_only_source': '222a775b21472f9ad99313c51940da8d7c2e2029d2dddd9d8b38fa45e4164b63',
        'r14': '067ba4622a51fc62c320bfd01a96a04aa614a6f798ef46757669d4faa97404f7'},
    'status': 'Native correctness and matched diagnostic measurement; independent R14 soundness/privacy reviews still required before activation.',
}
(HERE / 'MATCHED_R13_R14_COMPARISON.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(rows, indent=2))
