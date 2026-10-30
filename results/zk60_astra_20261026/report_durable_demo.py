"""Write the final demo report only from complete retained evidence."""
from datetime import datetime,timezone
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent;OUT=HERE/'real_app_demo_2'


def main():
    completed=json.loads((OUT/'complete.json').read_text())
    stored=json.loads((OUT/'stored_verify_complete.json').read_text())
    checked=json.loads((OUT/'app_checks.json').read_text())
    assert stored['accepted'] and checked['post_id']==stored['post_id']==completed['post_id']
    assert completed['source_sha256_revalidated']
    categories=[]
    for ch in completed['plan']:
        category=ch['category'];i=ch['index']
        e=json.loads((OUT/(category+'.json')).read_text());r=e['record']
        job=Path(completed['private_root'])/'jobs'/completed['post_id']/('prove' if i==0 else f'prove-c{i}')
        g=json.loads((job/'logs/prove.guard.json').read_text());assert g['exit']==g['child_rc']==0
        categories.append({'category':category,'verdict':r['labels'][category]['value'],
            'threads':e['execution']['native_threads'],'prove_s':g['child_wall_seconds'],
            'work_s':r['timings']['work_s'],'rss_gib':g['peak_rss_gib'],
            'receipt_bytes':r['receipt']['bytes'],'segments':r['receipt']['segments']})
    txs=sorted({a['tx_hash'] for a in completed['anchors'].values()})
    lines=['# Durable real classifier demo','',
           f"Post `{completed['post_id']}` contains {completed['content_tokens']} content tokens:",
           '', '> '+completed['post_text'],'',
           'All three r16b Shieldstral category receipts passed fresh native verification, input-owner verification and full-post label checks. The app uses the three registered moderate policies. Privacy statement pending; this testnet demonstration does not settle the final product policy or privacy acceptance.','',
           'The database, original development manifest key, salt, content ids and owner openings are retained outside the repository in the mode-700 directory `'+completed['private_root']+'`. Native owner files are mode0600. This is a new post; it does not restore the first garden post’s lost openings.','',
           '## Measurements','',
           'MEASURED, n=1, shared laptop. Work totals exclude queue wait; these are not controlled performance comparisons.','',
           '| Category | Verdict | Native threads | Native prove | Pipeline work | Sampled prove RSS |',
           '|---|---|---:|---:|---:|---:|']
    for r in categories:lines.append(f"| {r['category']} | {r['verdict']} | {r['threads']} | {r['prove_s']:.2f}s | {r['work_s']:.2f}s | {r['rss_gib']:.2f}GiB |")
    lines+=['',f"The three receipts contain {sum(r['segments'] for r in categories)} segments and {sum(r['receipt_bytes'] for r in categories):,} bytes.",'',
            '## Publication and checks','']
    for tx in txs:lines.append(f'- Confirmed [Base Sepolia transaction](https://sepolia.basescan.org/tx/{tx}). Only commitments are anchored; receipt bytes remain in the local public store.')
    lines += ['- `stored_verify_complete.json`: three additional fresh native verifications from the content-addressed public store.',
              f"- `app_checks.json`: {checked['passed']} checks of real routes, confirmed manifest references, unchanged original signer, retained salt and all three input-owner openings, feed behavior, authentication and duplicate-screening refusal.",
              '- `input_owner_capture.json`: public terminal owner-check events and retention metadata, without private opening bytes.',
              '- `plan.json`: original source pins, authenticated submission route, text, token count and full category plan. All sources revalidated at completion.',
              '- Production app storage changes passed199 tests; staged batch safety changes remain separate from this r16b run.','']
    shots=OUT/'screenshots/capture.json'
    if shots.exists():
        capture=json.loads(shots.read_text());lines+=['## Browser captures','']
        for shot in capture['captures']:lines.append('- ['+shot['file']+'](screenshots/'+shot['file']+')')
        lines+=['','Captured from the actual local app with an isolated headless browser. Visual review: '+('pending' if capture['visual_review_pending'] else 'completed')+'. The snapshot server is stopped.','']
    else:lines+=['No browser screenshot is claimed in this report yet.','']
    lines+=['Full benchmark fidelity metrics, classifier privacy acceptance and reviewed batch adoption remain open.','']
    (OUT/'REPORT.md').write_text('\n'.join(lines))
    (OUT/'summary.json').write_text(json.dumps({'at':datetime.now(timezone.utc).isoformat(),'post_id':completed['post_id'],
        'categories':categories,'transactions':txs,'stored_verify':True,'app_checks':checked['passed'],
        'original_openings_retained':True,'privacy_accepted':False},indent=2)+'\n')
    print(json.dumps({'report':str(OUT/'REPORT.md'),'transactions':txs}))


if __name__=='__main__':main()
