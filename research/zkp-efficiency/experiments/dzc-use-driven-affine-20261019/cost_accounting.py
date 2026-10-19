#!/usr/bin/env python3
"""Read retained public clocks only; do not execute owner code or read receipts."""
import hashlib
import json
import os
import re
import resource
import signal
import time
from pathlib import Path

H = Path(__file__).resolve().parent
R = Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017')

def main():
    tick = time.perf_counter()
    os.nice(19)
    cpu = min(os.sched_getaffinity(0)); os.sched_setaffinity(0, {cpu})
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU, (59,59)); signal.alarm(59)
    out = []
    pins = []
    for name in ['r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu',
                 'r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu-quiet',
                 'r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu']:
        f = R/name/'prove.log'
        raw = f.read_bytes(); lines = raw.decode().splitlines()
        pins.append(dict(path=str(f), sha256=hashlib.sha256(raw).hexdigest()))
        ds = []; total_blocks = 0; event = None
        for line in lines:
            if line.startswith('PB-TIMING prove |'):
                fields = [q.strip() for q in line.split('|')]
                if fields[1].startswith('slot 14 03 D zero-check'):
                    ds.append(float(fields[3]))
                if fields[1].startswith('WALL CLOCK'):
                    total_blocks += 1
            if line.startswith('{'):
                d = json.loads(line)
                if d.get('event') == 'proved':
                    assert event is None
                    event = d
        # Independent line matching, plus explicit one-phase-per-block guard.
        regex_ds = [float(x) for x in re.findall(
            r'^PB-TIMING prove \| slot 14 03 D zero-check[^|]*\|[^|]*\|\s*([0-9.]+)\s*\|',
            raw.decode(), flags=re.M)]
        assert ds == regex_ds and len(ds) == total_blocks == event['blocks'] == 32
        assert event['rayon_threads'] == 16 and 'off' in event['gpu']
        assert event['receipt_bytes'] == 922711264
        d_seconds = sum(ds); elapsed = event['total_seconds']
        assert 0 < d_seconds < event['prove_run_seconds'] < elapsed
        row = dict(owner_run=name, context_tokens=128, blocks=32, passes=1,
                   device='Intel Core Ultra9 185H CPU,16Rayonthreads;GPUoff',
                   evidence='Carried owner clocks; no receipt reverified by researcher',
                   D_phase_seconds=d_seconds, D_phase_rows=len(ds),
                   app_total_seconds=elapsed, proof_region_seconds=event['prove_run_seconds'],
                   nested_witness_seconds=event['of_which_witness_seconds'],
                   nested_block_load_seconds=event['of_which_block_load_seconds'],
                   sealing_pass_seconds=event['sealing_pass_seconds'],
                   receipt_bytes=event['receipt_bytes'], serialization_seconds=None,
                   startup_fraction=None, steady_state_proved_rate=None,
                   diagnostic_positions_per_total_second=128/elapsed,
                   D_fraction_of_total=d_seconds/elapsed,
                   zero_cost_ALL_D_counterfactual_total_seconds=elapsed-d_seconds,
                   zero_cost_ALL_D_counterfactual_speedup=elapsed/(elapsed-d_seconds),
                   zero_cost_ALL_D_counterfactual_diagnostic_positions_per_second=128/(elapsed-d_seconds),
                   caveat='Delete-ALL-D ceiling for this CPU diagnostic only; candidate changes a subset of D arithmetic. Not a prediction, target acceptance, GPU ceiling or resident/decode slope.')
        if name.startswith('r6/'):
            report = R/name/'report.json'; b = report.read_bytes()
            pins.append(dict(path=str(report),sha256=hashlib.sha256(b).hexdigest()))
            rr = json.loads(b)
            assert rr['numbers']['prove']['total_seconds'] == elapsed
            assert rr['checks']['verify']['verified'] and rr['checks']['verify']['controls_refused'] == 11
            row['fresh_verify'] = rr['numbers']['verify']
            row['fresh_recheck'] = rr['numbers']['recheck']
            row['source_review'] = 'D24 independent R6 review accepts per-layer shift and re-verifies stack; no trained privacy acceptance.'
        out.append(row)
    result = dict(status='PASS', run_id='20261019T111854Z-5ff11116',
                  accounting=out, source_pins=pins, threads=1, cpu_affinity=[cpu],
                  wall_seconds=time.perf_counter()-tick,
                  rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  limits='59sCPU/wall,512MiBAS,one nice19 thread;read-only owner clocks')
    (H/'cost-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__ == '__main__':
    main()
