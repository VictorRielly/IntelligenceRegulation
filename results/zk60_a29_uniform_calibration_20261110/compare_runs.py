"""A29: the uniform-calibration export's held-out A1 figures side by side with the current
per-layer export's (Astra's original Mac replay) and Astra's layer-12 score candidate
(the current export with only L12's paired score shift, 0 refusals), all three analyzed
by the export lane's unchanged analyze_verdicts.py against the same float references.
Paired rows use Astra's compare_group (mac_score_comparison/compare.py, imported, unchanged).

usage: compare_runs.py --uniform RUN_DIR   (writes comparison.json and comparison.md here)
"""
import argparse
import importlib.util
import json

import a29lib as A

RUNS = {'current': A.ASTRA / 'mac_evaluation/full', 'l12_candidate': A.ASTRA / 'mac_score_full_evaluation/full'}
HEADS = ('refusal_free', 'calibrated')
spec = importlib.util.spec_from_file_location('astra_compare', A.ASTRA / 'mac_score_comparison/compare.py')
astra = importlib.util.module_from_spec(spec); spec.loader.exec_module(astra)


def load(run):
    complete, fidelity = A.read(run / 'complete.json'), A.read(run / 'fidelity.json')
    A.require(A.sha(run / 'verdicts.json') == complete['verdicts_sha256'] == fidelity['integer_source_sha256'], 'binding')
    A.require(fidelity['all_12_A1_sets_complete'], 'all twelve A1 sets')
    return A.read(run / 'verdicts.json')['rows'], fidelity


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--uniform', type=A.Path, required=True)
    a = ap.parse_args()
    runs = {**RUNS, 'uniform': a.uniform}
    data = {k: load(v) for k, v in runs.items()}
    floats = {k: v[1]['float_source_sha256'] for k, v in data.items()}
    A.require(len({json.dumps(v, sort_keys=True) for v in floats.values()}) == 1, 'float references differ')
    inputs = A.read(A.EXPORT_LANE / 'evaluation_inputs/input.json')['rows']
    groups = {}
    for i, row in enumerate(inputs):
        groups.setdefault(f"{row['dataset']}/{row['template']}", []).append(i)
    table, paired = {}, {}
    for g, idx in sorted(groups.items()):
        dataset, template = g.split('/')
        suffix = '_le168_strat300' if dataset == 'openai_mod' else ''
        ref = {r['id']: r for r in map(json.loads, (A.ROOT / 'results/zk60_shieldstral_prep_20261021/bench' /
                                                      f'{dataset}_{template}{suffix}.jsonl').read_text().splitlines())}
        for head in HEADS:
            row = {}
            for name, (rows, fid) in data.items():
                h = fid['sets'][g]['heads'][head]; acc = h['accepted_only']
                row[name] = {'refused': h['refused'], 'accepted': acc['n'], 'total': h['n'],
                             'agreement_weighted': acc['agreement_weighted'], 'float_f1': acc['float']['f1'],
                             'integer_f1': acc['integer']['f1'], 'median_abs_margin_error': h['absolute_margin_error_quantiles']['0.5'],
                             'max_abs_margin_error': h['absolute_margin_error_quantiles']['1']}
            table[f'{g}|{head}'] = row
            before = [data['current'][0][i] for i in idx]
            for other in ('uniform',):
                after = [data[other][0][i] for i in idx]
                c = astra.compare_group(before, after, ref, head)
                c.pop('changed_or_refused_rows')
                paired[f'{g}|{head}|current_vs_{other}'] = c
            after = [data['uniform'][0][i] for i in idx]
            before = [data['l12_candidate'][0][i] for i in idx]
            c = astra.compare_group(before, after, ref, head); c.pop('changed_or_refused_rows')
            paired[f'{g}|{head}|l12_candidate_vs_uniform'] = c
    totals = {name: {'stack_refused_items': sum(r['stack_refused'] for r in rows),
                     'refused_rows_by_head': {h: sum(r['stack_refused'] or r['heads'][h]['head_refused'] for r in rows) for h in HEADS}}
              for name, (rows, _) in data.items()}
    out = {'runs': {k: str(v) for k, v in runs.items()}, 'totals': totals, 'table': table, 'paired': paired,
           'float_source_sha256': floats['uniform'],
           'scope': 'held-out with respect to the A29 design (chosen on the 192 calibration sequences only); '
                    'the 4,872 rows were seen before by the current export lane (L12 candidate chosen after them)'}
    A.record(A.HERE / 'comparison.json', out)
    f = lambda x: '—' if x is None else f'{x:.4f}'
    lines = ['| Group | Head | Refused (cur / L12 / uni) | Weighted agreement, accepted rows (cur / L12 / uni) | '
             'Float F1 | Integer F1 (cur / L12 / uni) | Paired cur vs uni: common rows, decision changes |',
             '|---|---|---:|---:|---:|---:|---:|']
    for key, row in table.items():
        g, head = key.split('|')
        p = paired[f'{key}|current_vs_uniform']
        lines.append(f"| {g} | {head} | {row['current']['refused']} / {row['l12_candidate']['refused']} / {row['uniform']['refused']} | "
                     f"{f(row['current']['agreement_weighted'])} / {f(row['l12_candidate']['agreement_weighted'])} / {f(row['uniform']['agreement_weighted'])} | "
                     f"{f(row['uniform']['float_f1'])} | {f(row['current']['integer_f1'])} / {f(row['l12_candidate']['integer_f1'])} / {f(row['uniform']['integer_f1'])} | "
                     f"{p['common_accepted']}, {p['common_decision_changes']} |")
    (A.HERE / 'comparison.md').write_text('\n'.join(lines) + '\n')
    print(json.dumps(totals), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
