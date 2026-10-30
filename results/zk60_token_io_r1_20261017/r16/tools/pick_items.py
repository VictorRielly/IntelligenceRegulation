#!/usr/bin/env python3
"""Token round 16: pick ONE real short item per D37 category (moderate template) from Astra's A1 evaluation inputs
(read only; results/zk60_shieldstral_export_20261026/evaluation_inputs/: input.json, ids.npy, offsets.npy) and
write its content ids (the item minus the policy's prefix and suffix) to an owner-private file (0600) under
~/zk60-artifacts/token-io/r16-items/<category>/content.ids, plus the seq-dir item list for r16_write_item_activations.

usage: pick_items.py list            (counts of candidates; no content printed)
       pick_items.py write           (writes the three content files + items.tsv; prints lengths and row ids only)
Rule: template mod_<cat>, 20 <= content_tokens <= 40, the dataset's first such row in file order (deterministic);
the content is checked: every id >= 1000 (no control id, B-2) and prefix/suffix equal the policy's.
"""
import json, os, sys, hashlib
import numpy as np

BASE = '/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/evaluation_inputs'
OUT = os.path.expanduser('~/zk60-artifacts/token-io/r16-items')
CATS = [('mod_sexual', 'shieldstral-1.0-3b-moderate-sexual/1'), ('mod_violence', 'shieldstral-1.0-3b-moderate-violence/1'), ('mod_hate', 'shieldstral-1.0-3b-moderate-hate/1')]


def main():
    mode = sys.argv[1]
    d = json.load(open(f'{BASE}/input.json'))
    ids = np.load(f'{BASE}/ids.npy', allow_pickle=False)
    off = np.load(f'{BASE}/offsets.npy', allow_pickle=False)
    rows = d['rows']
    assert len(off) == len(rows) + 1, (len(off), len(rows))
    picks = []
    for tmpl, pid in CATS:
        pol = d['policies'][tmpl]
        cands = [i for i, r in enumerate(rows) if r['template'] == tmpl and 20 <= r['content_tokens'] <= 40]
        print(tmpl, 'candidates', len(cands))
        i = cands[0]
        r = rows[i]
        item = ids[off[i]:off[i + 1]].astype(np.int64).tolist()
        p0, s = len(pol['prefix']), len(pol['suffix'])
        assert len(item) == r['T'] == p0 + r['content_tokens'] + s, (len(item), r['T'])
        assert item[:p0] == pol['prefix'] and item[len(item) - s:] == pol['suffix']
        content = item[p0:len(item) - s]
        assert all(x >= 1000 for x in content), 'a control id at a content position'
        picks.append((tmpl, pid, i, r, content))
        print(f'  pick row {i} dataset {r["dataset"]} content_tokens {len(content)} (label withheld here)')
    if mode != 'write':
        return
    os.makedirs(OUT, mode=0o700, exist_ok=True)
    lines = []
    record = []
    for tmpl, pid, i, r, content in picks:
        cd = os.path.join(OUT, tmpl)
        os.makedirs(cd, mode=0o700, exist_ok=False)
        cf = os.path.join(cd, 'content.ids')
        fd = os.open(cf, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        os.write(fd, (','.join(map(str, content)) + '\n').encode())
        os.close(fd)
        lines.append(f'{pid}\t{cf}\t{os.path.join(cd, "seq")}')
        record.append({'template': tmpl, 'policy': pid, 'row_index': i, 'dataset': r['dataset'], 'row_id_sha256': r['id'],
                       'content_tokens': len(content), 'content_file': cf})
    fd = os.open(os.path.join(OUT, 'items.tsv'), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, ('\n'.join(lines) + '\n').encode())
    os.close(fd)
    json.dump({'source_input_json_sha256': hashlib.sha256(open(f'{BASE}/input.json', 'rb').read()).hexdigest(), 'items': record},
              open('/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/items.json', 'w'), indent=1)
    print('written', OUT)


if __name__ == '__main__':
    main()
