"""D24 review r9: independent n_col = |{0} U exp outputs| per layer, from the
exported exp.bin of each layer (int64 LE, 256 entries), checked against the
manifest's sha256; cap 32 (D30 condition 6)."""
import hashlib, json, os, struct, sys
out = {}
for name, d in [(a.split('=')[0], a.split('=')[1]) for a in sys.argv[1:]]:
    prof = json.load(open(os.path.join(d, 'profile.json')))
    rows = []
    for L in prof['layers']:
        ld = os.path.join(d, L['dir'])
        man = json.load(open(os.path.join(ld, 'manifest.json')))
        ent = man['arrays']['exp']
        b = open(os.path.join(ld, ent['file']), 'rb').read()
        assert hashlib.sha256(b).hexdigest() == ent['sha256'], (name, L)
        vals = struct.unpack('<%dq' % (len(b) // 8), b)
        ncol = len({0} | set(vals))
        rows.append({'layer': L['layer'], 'exp_e_s': man['constants'].get('exp_e_s'), 'n_col': ncol,
                     'monotone_nonincreasing': all(vals[i] >= vals[i + 1] for i in range(len(vals) - 1)),
                     'min': min(vals), 'max': max(vals)})
    out[name] = {'layers': len(rows), 'worst_n_col': max(r['n_col'] for r in rows),
                 'over_cap_32': [r['layer'] for r in rows if r['n_col'] > 32],
                 'all_monotone': all(r['monotone_nonincreasing'] for r in rows),
                 'e_s_counts': {str(k): sum(1 for r in rows if r['exp_e_s'] == k) for k in sorted({r['exp_e_s'] for r in rows})},
                 'rows': rows}
    print(name, 'layers', len(rows), 'worst n_col', out[name]['worst_n_col'], 'over cap', out[name]['over_cap_32'], 'monotone', out[name]['all_monotone'], 'e_s', out[name]['e_s_counts'])
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'r9_ncol_check.json'), 'w'), indent=1)
