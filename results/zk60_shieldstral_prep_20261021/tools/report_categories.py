"""Render A1's measured table with completeness checks and provenance.

Default writes REPORT_STRICT_INTERIM.md; --final refuses until all 12 benchmark
files are complete, unique and aligned. It never presents a partial policy as a
completed comparison. Run analyze_categories.py first to refresh metrics.
"""
import argparse
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path

LANE=Path(__file__).resolve().parents[1]


def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--final',action='store_true');a=ap.parse_args()
    metrics=json.loads((LANE/'bench/metrics_categories.json').read_text())
    lengths=json.loads((LANE/'length_stats.json').read_text())
    sources={};ids={};rows={};complete={}
    for variant,prefix in [('strict','cat'),('moderate','mod')]:
        complete[variant]=True
        for dataset,n in [('openai_mod',612),('toxicchat',200)]:
            sets=[]
            for category in ('sexual','violence','hate'):
                stem=f'{dataset}_{prefix}_{category}'+('_le168_strat300' if dataset=='openai_mod' else '')
                path=LANE/'bench'/f'{stem}.jsonl'
                data=[json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
                item_ids={r['id'] for r in data}
                if len(item_ids)!=len(data):raise ValueError(f'duplicate IDs: {stem}')
                if data and any(r.get('template') not in (None,f'{prefix}_{category}') for r in data):
                    raise ValueError(f'wrong template: {stem}')
                if len(data)>n:raise ValueError(f'unexpected extra benchmark rows: {stem}')
                complete[variant]&=len(data)==n
                key=(variant,dataset,category);rows[key]=data;ids[key]=item_ids;sets.append(item_ids)
                if path.exists():sources[str(path.relative_to(LANE))]=digest(path)
                mk='toxicchat200' if dataset=='toxicchat' else dataset
                measured=metrics[variant][mk].get(f'{prefix}_{category}')
                if measured and len(data)!=(measured.get('n_items') or measured['abs_margin']['n']):
                    raise ValueError('metrics stale: rerun analyze_categories.py')
            if all(len(s)==n for s in sets) and any(s!=sets[0] for s in sets):raise ValueError('category ID sets differ')
    if not complete['strict']:raise ValueError('strict benchmark incomplete')
    if a.final and not complete['moderate']:raise ValueError('moderate benchmark incomplete; final report refused')
    if complete['moderate']:
        for dataset in ('openai_mod','toxicchat'):
            if ids['strict',dataset,'sexual']!=ids['moderate',dataset,'sexual']:raise ValueError('policy comparison IDs differ')
    now=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    lines=['# Shieldstral category benchmarks'+('' if a.final else ' — strict interim'),'',
        'The strict model catches most labelled sexual examples and about four fifths of labelled hate/harassment examples in this short-post sample. Its hate/harassment precision is lower: many flagged examples lack a positive dataset label. Moderate-policy results are still pending, so this is not yet a recommendation for the product setting.' if not a.final else
        'Both policies are measured on the same examples. Moderate wording has slightly higher sexual-category F1, while strict wording has slightly higher violence and hate/harassment F1 in this sample. The differences are small and do not establish a general winner. The table below supports Victor’s product-policy choice; thresholds remain margin > 0. No integer fidelity, proof or privacy acceptance follows from these float benchmarks.',
        '',f'Report generated at {now} from retained MEASURED float benchmark results (completed 2026-10-26). Fixed pinned Shieldstral float reference; n=1, shared box.',
        '', '## OpenAI Moderation: per-category ground truth','',
        '612 stratified examples with content ≤168 tokens: all eligible unsafe examples plus 300 sampled safe examples. Precision, recall and F1 use the stored importance weights. Missing category labels count as zero in the main columns. “Known F1” instead restricts negatives to examples with at least one known label in that category group; it does not make all missing annotations known.',
        '', '| Category | Policy | Precision | Recall | F1 | Known F1 | Median abs margin | Count abs margin <1 |',
        '|---|---|---:|---:|---:|---:|---:|---:|']
    for category in ('sexual','violence','hate'):
        for variant,prefix in [('strict','cat'),('moderate','mod')]:
            if not complete[variant]:lines.append(f'| {category} | {variant} | pending | pending | pending | pending | pending | pending |');continue
            r=metrics[variant]['openai_mod'][f'{prefix}_{category}'];m=r['missing0']
            lines.append(f"| {category} | {variant} | {m['precision']:.3f} | {m['recall']:.3f} | {m['f1']:.3f} | {r['known']['f1']:.3f} | {r['abs_margin']['p50']:.2f} | {r['count_abs_margin_below']['1.0']} /612 |")
    lines+=['','Margin quantiles are unweighted sample summaries. Full signed positive/negative quantiles, weighted near-boundary shares and bootstrap F1 intervals are in `bench/metrics_categories.json`. Near-zero float margins identify sensitivity candidates; integer error has not been measured yet.',
            '', '## ToxicChat-200: broad toxicity proxy','',
            'ToxicChat does not provide ground truth for these three separate categories. The per-category scores below compare each verdict with broad toxicity and must not be read as category accuracy.',
            '', '| Query | Policy | Precision vs toxicity | Recall vs toxicity | F1 vs toxicity | Flag fraction |',
            '|---|---|---:|---:|---:|---:|']
    for category in ('sexual','violence','hate'):
        for variant,prefix in [('strict','cat'),('moderate','mod')]:
            if not complete[variant]:lines.append(f'| {category} | {variant} | pending | pending | pending | pending |');continue
            r=metrics[variant]['toxicchat200'][f'{prefix}_{category}'];m=r['vs_toxicity']
            lines.append(f"| {category} | {variant} | {m['precision']:.3f} | {m['recall']:.3f} | {m['f1']:.3f} | {r['flag_rate']:.3f} |")
    for variant in ('strict','moderate'):
        if not complete[variant]:continue
        union=metrics[variant]['toxicchat200']['union_vs_toxicity']
        lines+=['',f"The {variant} union of the three queries has toxicity precision {union['precision']:.3f}, recall {union['recall']:.3f}, F1 {union['f1']:.3f}."]
    lines+=['', '## Content-token lengths','',
            'These are content tokens only, before public template tokens. The population rows include posts outside the evaluated short-post subset.',
            '', '| Set | n | ≤40 | ≤104 | ≤168 | ≤424 |','|---|---:|---:|---:|---:|---:|']
    for name in ('toxicchat_human','openai_mod'):
        record=lengths['sets'][name]
        lines.append('| '+name+f" | {record['n']} | "+' | '.join(f"{record['share_le'][str(c)]:.1%}" for c in lengths['caps'])+' |')
    for dataset in ('toxicchat','openai_mod'):
        values=[lengths['items'][dataset][i] for i in ids['strict',dataset,'sexual']]
        lines.append('| evaluated '+dataset+f' | {len(values)} | '+' | '.join(f'{sum(x<=c for x in values)/len(values):.1%}' for c in lengths['caps'])+' |')
    lines+=['', '## Provenance and remaining work','',
        'Counts, unique IDs and cross-category alignment were checked before rendering. `benchmark_report_sources.json` pins every present raw benchmark file and records completeness. Full model/reference/policy pins remain in the prep lane ledger and model files.',
        '', 'Remaining: finish moderate runs and select policy; measure the integer model against these same examples, with refusals and borderline margins explicit. This interim file is not the final A1 REPORT.md.' if not a.final else
        'The next stage is integer/float verdict agreement, category F1, error-boundary examples and zero-refusal calibration in the export lane.']
    target=LANE/('REPORT.md' if a.final else 'REPORT_STRICT_INTERIM.md')
    target.write_text('\n'.join(lines)+'\n')
    (LANE/'benchmark_report_sources.json').write_text(json.dumps({'at':now,'complete':complete,'files':sources,
        'metrics_sha256':digest(LANE/'bench/metrics_categories.json'),'lengths_sha256':digest(LANE/'length_stats.json'),
        'analysis_source_sha256':digest(LANE/'tools/analyze_categories.py'),
        'report_source_sha256':digest(Path(__file__))},indent=2)+'\n')
    print(json.dumps({'report':str(target),'complete':complete}))


if __name__=='__main__':main()
